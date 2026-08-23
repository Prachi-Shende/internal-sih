# routers/incidents.py
"""
Incident router — full incident lifecycle management.

Endpoints:
  POST /incident                       — Create incident (I Feel Unsafe trigger)
  POST /incident/{id}/event            — Append a timeline event
  POST /incident/{id}/resolve          — Mark incident as RESOLVED
  GET  /incident/{id}                  — Full incident + timeline (for P6)
  GET  /incidents                      — List all incidents (filterable)
"""
import json
import time
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import Incident, IncidentEvent
from schemas import IncidentCreate, IncidentEventCreate

router = APIRouter()


def _build_response(incident: Incident, db: Session) -> dict:
    """Build a full incident response with sorted timeline events."""
    events = (
        db.query(IncidentEvent)
        .filter(IncidentEvent.incident_id == incident.id)
        .order_by(IncidentEvent.timestamp)
        .all()
    )
    return {
        "id": incident.id,
        "session_id": incident.session_id,
        "started_at": incident.started_at.isoformat() + "Z" if incident.started_at else None,
        "resolved_at": incident.resolved_at.isoformat() + "Z" if incident.resolved_at else None,
        "status": incident.status,
        "risk_level": incident.risk_level,
        "lat": incident.lat,
        "lon": incident.lon,
        "location_source": incident.location_source,
        "location_confidence": incident.location_confidence,
        "blockchain_hash": incident.blockchain_hash,
        "events": [
            {
                "id": e.id,
                "incident_id": e.incident_id,
                "timestamp": e.timestamp.isoformat() + "Z" if e.timestamp else None,
                "event_type": e.event_type,
                "description": e.description,
                "data": json.loads(e.data) if e.data else None,
            }
            for e in events
        ],
    }


@router.post("", status_code=201)
def create_incident(payload: IncidentCreate, db: Session = Depends(get_db)):
    """
    Create a new incident. Called when tourist presses 'I Feel Unsafe'.
    ID is auto-generated as INC-{unix_ms}.
    """
    incident_id = f"INC-{int(time.time() * 1000)}"
    incident = Incident(
        id=incident_id,
        session_id=payload.session_id,
        started_at=datetime.now(timezone.utc),
        status="ACTIVE",
        risk_level=payload.risk_level,
        lat=payload.lat,
        lon=payload.lon,
        location_source=payload.location_source,
        location_confidence=payload.location_confidence,
        blockchain_hash=payload.blockchain_hash,
    )
    db.add(incident)
    db.commit()
    db.refresh(incident)

    # Auto-log SOS event
    sos_event = IncidentEvent(
        incident_id=incident_id,
        timestamp=datetime.now(timezone.utc),
        event_type="SOS_TRIGGERED",
        description="Tourist triggered I Feel Unsafe — incident created.",
        data=json.dumps({"risk_level": payload.risk_level, "source": payload.location_source}),
    )
    db.add(sos_event)
    db.commit()

    return _build_response(incident, db)


@router.post("/{incident_id}/event")
def add_incident_event(
    incident_id: str,
    payload: IncidentEventCreate,
    db: Session = Depends(get_db),
):
    """Append a timeline event to an existing incident (called by P4)."""
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail=f"Incident '{incident_id}' not found")

    event = IncidentEvent(
        incident_id=incident_id,
        timestamp=datetime.now(timezone.utc),
        event_type=payload.event_type,
        description=payload.description,
        data=json.dumps(payload.data) if payload.data else None,
    )
    db.add(event)
    db.commit()
    return _build_response(incident, db)


@router.post("/{incident_id}/resolve")
def resolve_incident(incident_id: str, db: Session = Depends(get_db)):
    """Mark an incident as RESOLVED and record the resolution time."""
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail=f"Incident '{incident_id}' not found")

    incident.status = "RESOLVED"
    incident.resolved_at = datetime.now(timezone.utc)

    # Auto-log resolution event
    resolve_event = IncidentEvent(
        incident_id=incident_id,
        timestamp=datetime.now(timezone.utc),
        event_type="INCIDENT_RESOLVED",
        description="Incident marked as resolved.",
        data=None,
    )
    db.add(resolve_event)
    db.commit()
    db.refresh(incident)
    return _build_response(incident, db)


@router.get("")
def list_incidents(
    session_id: Optional[str] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """Return all incidents, sorted by start time descending. Filterable by session and status."""
    query = db.query(Incident)
    if session_id:
        query = query.filter(Incident.session_id == session_id)
    if status:
        query = query.filter(Incident.status == status.upper())
    incidents = query.order_by(Incident.started_at.desc()).all()
    return [_build_response(i, db) for i in incidents]


@router.get("/{incident_id}")
def get_incident(incident_id: str, db: Session = Depends(get_db)):
    """Return a full incident with its complete event timeline. Used by P6."""
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident:
        raise HTTPException(status_code=404, detail=f"Incident '{incident_id}' not found")
    return _build_response(incident, db)
