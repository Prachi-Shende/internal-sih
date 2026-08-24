# routers/safe_locations.py
"""
Safe locations router — read/add safe locations (hospitals, police, hotels, etc.).

Endpoints:
  GET  /safe-locations   — All safe locations (with optional filters + proximity sort)
  POST /safe-locations   — Add a new safe location
"""
import math
from typing import Optional, List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database import get_db
from models import SafeLocation
from schemas import SafeLocationCreate, SafeLocationResponse

router = APIRouter()


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


@router.get("", response_model=List[SafeLocationResponse])
def get_safe_locations(
    type: Optional[str] = Query(None, description="Filter by type: hospital, police, hotel, railway, tourist_centre"),
    lat: Optional[float] = Query(None, description="Tourist latitude for proximity sort"),
    lon: Optional[float] = Query(None, description="Tourist longitude for proximity sort"),
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """
    Return safe locations.
    If lat+lon provided, results are sorted nearest-first (Haversine).
    """
    query = db.query(SafeLocation)
    if type:
        query = query.filter(SafeLocation.type == type.lower())
    locations = query.all()

    if lat is not None and lon is not None:
        locations = sorted(
            locations,
            key=lambda loc: haversine_m(lat, lon, loc.latitude, loc.longitude),
        )

    return locations[:limit]


@router.post("", response_model=SafeLocationResponse, status_code=201)
def create_safe_location(payload: SafeLocationCreate, db: Session = Depends(get_db)):
    """Add a new safe location to the database."""
    location = SafeLocation(
        name=payload.name,
        latitude=payload.latitude,
        longitude=payload.longitude,
        type=payload.type.lower(),
        availability=payload.availability,
        phone=payload.phone,
    )
    db.add(location)
    db.commit()
    db.refresh(location)
    return location
