# routers/hotspots.py
"""
Hotspots router — crime hotspot read/upload for P2.

Endpoints:
  GET  /hotspots          — All hotspots (with optional filters)
  POST /hotspots/upload   — Upload raw crime records → trigger pipeline
"""
import math
from typing import Optional, List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database import get_db
from models import Hotspot
from schemas import HotspotListResponse, HotspotResponse
from pipeline.pipeline_runner import run_full_pipeline

router = APIRouter()


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


@router.get("", response_model=HotspotListResponse)
def get_hotspots(
    risk_level: Optional[str] = Query(None, description="Filter by 'HIGH', 'MEDIUM', or 'LOW'"),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    radius_m: Optional[int] = Query(None, description="Return only hotspots within this radius (metres)"),
    db: Session = Depends(get_db),
):
    """
    Return all hotspots.
    Optional filters:
      - risk_level: filter by HIGH/MEDIUM/LOW
      - lat + lon + radius_m: spatial proximity filter
    """
    query = db.query(Hotspot)

    if risk_level:
        query = query.filter(Hotspot.risk_level == risk_level.upper())

    hotspots = query.order_by(Hotspot.hotspot_score.desc()).all()

    # Spatial filter
    if lat is not None and lon is not None and radius_m is not None:
        hotspots = [
            h for h in hotspots
            if haversine_m(lat, lon, h.center_lat, h.center_lon) <= radius_m
        ]

    return HotspotListResponse(
        hotspots=[HotspotResponse.model_validate(h) for h in hotspots],
        total=len(hotspots),
    )


@router.post("/upload")
def upload_crime_data(records: List[dict], db: Session = Depends(get_db)):
    """
    Accept a JSON array of raw crime incident records.
    Triggers the full pipeline (ingest → clean → score → store).
    Returns summary of hotspots generated.
    """
    result = run_full_pipeline(records, db)
    return {
        "message": "Pipeline completed successfully",
        **result,
    }
