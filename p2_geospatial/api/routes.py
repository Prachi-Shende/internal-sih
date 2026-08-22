"""
routes.py
---------
FastAPI routes exposed by the P2 Geospatial Intelligence microservice.

Endpoints
---------
GET  /health                      — liveness check
GET  /hotspots                    — return all computed hotspots
GET  /hotspots/nearby             — hotspots within a radius of a lat/lon
GET  /safe-locations              — nearby safe places (Google Places)
POST /check-geofence              — P1 sends location; we return geo-fence state
GET  /map-config                  — frontend gets the Google Maps API key
"""

import json
import os
from pathlib import Path

from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from core.geofence_engine import check_geofence, haversine
from core.places_service import get_nearby_safe_places

load_dotenv()

router = APIRouter()

# ─── Load hotspots once at startup ───────────────────────────────────────────
_HOTSPOTS_PATH = os.getenv("HOTSPOTS_OUTPUT_PATH", "data/hotspots_processed.json")
_hotspots: list[dict] = []

def load_hotspots_from_disk():
    global _hotspots
    p = Path(_HOTSPOTS_PATH)
    if p.exists():
        with open(p) as f:
            _hotspots = json.load(f)
        print(f"[routes] Loaded {len(_hotspots)} hotspots from {p}")
    else:
        print(f"[routes] WARNING: {p} not found. Run scripts/build_hotspots.py first.")
        _hotspots = []


# ─────────────────────────────────────────────────────────────────────────────
# Pydantic models
# ─────────────────────────────────────────────────────────────────────────────

class LocationPayload(BaseModel):
    """
    What P1 sends us every ~2 seconds.
    """
    lat:        float
    lon:        float
    source:     str   = "UNKNOWN"   # "GPS" or "PDR"
    confidence: float = 1.0         # 0.0 – 1.0


# ─────────────────────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/health")
def health():
    return {"status": "ok", "hotspots_loaded": len(_hotspots)}


@router.get("/hotspots")
def get_all_hotspots(risk: str | None = Query(None, description="Filter by risk: LOW, MEDIUM, HIGH")):
    """
    Return all hotspots (optionally filtered by risk level).
    P6 calls this to draw coloured circles on the map.
    """
    if not _hotspots:
        raise HTTPException(503, "Hotspots not loaded. Run build_hotspots.py first.")
    if risk:
        return [h for h in _hotspots if h["risk"] == risk.upper()]
    return _hotspots


@router.get("/hotspots/nearby")
def get_nearby_hotspots(
    lat:    float = Query(..., description="User latitude"),
    lon:    float = Query(..., description="User longitude"),
    radius: int   = Query(1000, description="Search radius in metres"),
):
    """
    Return only hotspots within `radius` metres of the given point.
    """
    if not _hotspots:
        raise HTTPException(503, "Hotspots not loaded.")

    nearby = []
    for h in _hotspots:
        dist = haversine(lat, lon, h["center_lat"], h["center_lon"])
        if dist <= radius:
            nearby.append({**h, "distance_m": round(dist, 1)})

    nearby.sort(key=lambda x: x["distance_m"])
    return nearby


@router.get("/safe-locations")
def safe_locations(
    lat:    float = Query(..., description="User latitude"),
    lon:    float = Query(..., description="User longitude"),
    radius: int   = Query(1500, description="Search radius in metres"),
):
    """
    Return nearby safe places (police, hospitals, hotels …).
    P3 uses this to rank safe-haven options.
    """
    places = get_nearby_safe_places(lat, lon, radius_m=radius)
    return places


@router.post("/check-geofence")
def check_geofence_endpoint(payload: LocationPayload):
    """
    Core endpoint called by P1 on every location update.

    Returns a GeofenceEvent dict:
        geofence_state      — OUTSIDE / APPROACHING / INSIDE
        hotspot_id          — which hotspot (or null)
        risk                — HIGH / MEDIUM / null
        reported_incidents  — int or null
        distance_m          — metres to nearest relevant hotspot
        location_source     — GPS or PDR (passed through from P1)
    """
    if not _hotspots:
        raise HTTPException(503, "Hotspots not loaded.")

    event = check_geofence(
        user_lat        = payload.lat,
        user_lon        = payload.lon,
        hotspots        = _hotspots,
        location_source = payload.source,
    )
    return event.to_dict()


@router.get("/map-config")
def map_config():
    """
    P6 calls this once to get the Google Maps API key.
    (Avoids hardcoding the key in frontend code.)
    """
    key = os.getenv("GOOGLE_MAPS_API_KEY", "")
    if not key or key == "YOUR_KEY_HERE":
        return {"api_key": None, "warning": "No Google Maps API key configured"}
    return {"api_key": key}
