# routers/location.py
"""
Location router — handles GPS/PDR location data from P1.

Endpoints:
  POST /location        — Save a LocationEstimate, return it + nearest hotspot
  GET  /location/latest — Latest location for a session_id
"""
import math
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import LocationEstimate as LocationEstimateModel, Hotspot
from schemas import LocationEstimate

router = APIRouter()


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return distance in metres between two lat/lon points (Haversine formula)."""
    R = 6_371_000  # Earth radius in metres
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


@router.post("", status_code=201)
def create_location(payload: LocationEstimate, db: Session = Depends(get_db)):
    """
    Save a location estimate from P1.
    Also looks up the nearest crime hotspot for immediate context.
    """
    record = LocationEstimateModel(
        lat=payload.lat,
        lon=payload.lon,
        source=payload.source,
        confidence=payload.confidence,
        timestamp=datetime.now(timezone.utc),
        session_id=payload.session_id,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    # Find nearest hotspot
    hotspots = db.query(Hotspot).all()
    nearest_hotspot = None
    if hotspots:
        closest = min(
            hotspots,
            key=lambda h: haversine_m(payload.lat, payload.lon, h.center_lat, h.center_lon),
        )
        dist = haversine_m(payload.lat, payload.lon, closest.center_lat, closest.center_lon)
        nearest_hotspot = {
            "id": closest.id,
            "risk_level": closest.risk_level,
            "distance_m": round(dist),
            "reported_incidents": closest.reported_incidents,
        }

    return {
        "id": record.id,
        "lat": record.lat,
        "lon": record.lon,
        "source": record.source,
        "confidence": record.confidence,
        "timestamp": record.timestamp.isoformat() + "Z",
        "session_id": record.session_id,
        "nearest_hotspot": nearest_hotspot,
    }


@router.get("/latest")
def get_latest_location(session_id: str, db: Session = Depends(get_db)):
    """Return the most recent location estimate for a given session_id."""
    record = (
        db.query(LocationEstimateModel)
        .filter(LocationEstimateModel.session_id == session_id)
        .order_by(LocationEstimateModel.timestamp.desc())
        .first()
    )
    if not record:
        raise HTTPException(
            status_code=404,
            detail=f"No location found for session_id='{session_id}'",
        )
    return {
        "id": record.id,
        "lat": record.lat,
        "lon": record.lon,
        "source": record.source,
        "confidence": record.confidence,
        "timestamp": record.timestamp.isoformat() + "Z",
        "session_id": record.session_id,
    }
