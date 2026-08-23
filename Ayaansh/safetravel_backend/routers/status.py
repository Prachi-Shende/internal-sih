# routers/status.py
"""
Status and unified state router.

Endpoints:
  GET /status         — System health check (DB counts, connectivity)
  GET /unified-state  — Complete unified safety state for P6 dashboard (locked shape)
"""
import math
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import (
    Hotspot, SafeLocation, Incident,
    LocationEstimate as LocationEstimateModel,
    RiskAssessment, CommunicationEvent,
)
from schemas import UnifiedSafetyState

router = APIRouter()


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


@router.get("/status")
def get_status(db: Session = Depends(get_db)):
    """System health check — returns DB connectivity and table counts."""
    try:
        total_hotspots = db.query(Hotspot).count()
        total_safe_locations = db.query(SafeLocation).count()
        total_incidents = db.query(Incident).count()
        active_incidents = db.query(Incident).filter(Incident.status == "ACTIVE").count()
        db_status = "connected"
    except Exception as e:
        return {"status": "error", "database": str(e)}

    return {
        "status": "ok",
        "database": db_status,
        "total_hotspots": total_hotspots,
        "total_safe_locations": total_safe_locations,
        "total_incidents": total_incidents,
        "active_incidents": active_incidents,
    }


@router.get("/unified-state", response_model=UnifiedSafetyState)
def get_unified_state(session_id: str, db: Session = Depends(get_db)):
    """
    THE single object P6 uses for the main dashboard.
    Combines latest: location + risk assessment + nearest hotspot + comms + nearest safe location.
    Shape is LOCKED — do not rename fields.
    """
    # ── Latest location (required) ──────────────────────────────────────────
    location = (
        db.query(LocationEstimateModel)
        .filter(LocationEstimateModel.session_id == session_id)
        .order_by(LocationEstimateModel.timestamp.desc())
        .first()
    )
    if not location:
        raise HTTPException(
            status_code=404,
            detail=f"No state found for session_id='{session_id}'. "
                   "POST at least one location first.",
        )

    # ── Latest risk assessment ────────────────────────────────────────────────
    risk = (
        db.query(RiskAssessment)
        .filter(RiskAssessment.session_id == session_id)
        .order_by(RiskAssessment.timestamp.desc())
        .first()
    )

    # ── Nearest hotspot ───────────────────────────────────────────────────────
    hotspots = db.query(Hotspot).all()
    nearest_hotspot = None
    if hotspots:
        nearest_hotspot = min(
            hotspots,
            key=lambda h: haversine_m(location.lat, location.lon, h.center_lat, h.center_lon),
        )

    # ── Latest comms status (from active incident, if any) ────────────────────
    active_incident = (
        db.query(Incident)
        .filter(Incident.session_id == session_id, Incident.status == "ACTIVE")
        .order_by(Incident.started_at.desc())
        .first()
    )
    comms = None
    if active_incident:
        comms = (
            db.query(CommunicationEvent)
            .filter(CommunicationEvent.incident_id == active_incident.id)
            .order_by(CommunicationEvent.timestamp.desc())
            .first()
        )

    # ── Nearest safe location ─────────────────────────────────────────────────
    safe_locations = db.query(SafeLocation).all()
    nearest_safe = None
    nearest_safe_dist = None
    if safe_locations:
        nearest_safe = min(
            safe_locations,
            key=lambda s: haversine_m(location.lat, location.lon, s.latitude, s.longitude),
        )
        nearest_safe_dist = round(
            haversine_m(location.lat, location.lon, nearest_safe.latitude, nearest_safe.longitude)
        )

    return UnifiedSafetyState(
        lat=location.lat,
        lon=location.lon,
        confidence=location.confidence,
        source=location.source,
        risk=risk.risk_level if risk else "LOW",
        score=risk.score if risk else 0,
        hotspot_id=nearest_hotspot.id if nearest_hotspot else None,
        reported_incidents=nearest_hotspot.reported_incidents if nearest_hotspot else None,
        internet=comms.internet if comms else True,
        sms=comms.sms if comms else True,
        relay=comms.relay if comms else False,
        selected_channel=comms.selected_channel if comms else "INTERNET",
        nearest_safe_location=(
            {
                "name": nearest_safe.name,
                "distance_m": nearest_safe_dist,
                "type": nearest_safe.type,
            }
            if nearest_safe else None
        ),
    )
