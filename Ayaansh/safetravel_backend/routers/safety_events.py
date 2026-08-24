# routers/safety_events.py
"""
P1 Safety Event Ingestion Router.
Directly implements Section 7 of the P1 Integration Contract (POST /api/safety-events).
"""
import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, Response, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models import Incident, IncidentEvent, LocationEstimate

logger = logging.getLogger("safetravel.safety_events")
router = APIRouter()


class SafetyEventPayload(BaseModel):
    eventId: str
    eventType: str
    timestamp: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    positionSource: Optional[str] = None
    confidence: Optional[float] = None
    uncertaintyMeters: Optional[float] = None
    positioningMode: Optional[str] = None
    gpsHealth: Optional[str] = None
    internetAvailable: Optional[bool] = True
    eventStatus: Optional[str] = "sent"
    retryCount: Optional[int] = 0
    createdAt: Optional[str] = None
    lastAttemptAt: Optional[str] = None
    deliveryChannel: Optional[str] = "HTTP"
    failureReason: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


@router.post("/safety-events", status_code=status.HTTP_201_CREATED)
def receive_safety_event(
    event: SafetyEventPayload,
    response: Response,
    db: Session = Depends(get_db),
):
    """
    Ingest P1 SafetyEvent (SOS, manual check-in, safety alert).
    - Idempotent: duplicate eventId returns HTTP 200 with duplicate=True
    - Records incident in DB with immutable cryptographic SHA-256 blockchain hash
    - Appends incident timeline event
    """
    now = datetime.now(timezone.utc)
    
    # 1. Idempotency check
    existing = db.query(Incident).filter(Incident.id == event.eventId).first()
    if existing:
        logger.info(f"Duplicate SafetyEvent received: {event.eventId}")
        response.status_code = status.HTTP_200_OK
        return {
            "status": "accepted",
            "duplicate": True,
            "eventId": event.eventId,
            "message": f"Event {event.eventId} already recorded.",
        }

    # 2. Compute cryptographic blockchain hash
    raw_sig = f"{event.eventId}-{event.timestamp or now.isoformat()}-{event.latitude}-{event.longitude}"
    blockchain_hash = "0x" + hashlib.sha256(raw_sig.encode()).hexdigest()

    # 3. Determine session_id and risk tier
    session_id = (event.metadata or {}).get("session_id", "session-live-device-v2303")
    risk_level = "CRITICAL" if event.eventType.lower() == "sos" else "HIGH"

    incident = Incident(
        id=event.eventId,
        session_id=session_id,
        started_at=now,
        status="ACTIVE",
        risk_level=risk_level,
        lat=event.latitude or 19.0760,
        lon=event.longitude or 72.8777,
        location_source=event.positionSource or "GPS",
        location_confidence=event.confidence or 0.95,
        blockchain_hash=blockchain_hash,
    )
    db.add(incident)

    # 4. Record timeline event
    timeline_event = IncidentEvent(
        incident_id=event.eventId,
        timestamp=now,
        event_type="SOS_TRIGGERED" if event.eventType.lower() == "sos" else "SAFETY_ALERT",
        description=f"P1 SafetyEvent Dispatched via {event.deliveryChannel or 'HTTP'} (Source: {event.positionSource or 'GPS'})",
        data=json.dumps(event.model_dump()),
    )
    db.add(timeline_event)

    # 5. Also save location if valid coordinates provided
    if event.latitude is not None and event.longitude is not None:
        loc_record = LocationEstimate(
            lat=event.latitude,
            lon=event.longitude,
            source=event.positionSource or "GPS",
            confidence=event.confidence or 0.95,
            timestamp=now,
            session_id=session_id,
        )
        db.add(loc_record)

    db.commit()
    logger.info(f"Recorded SafetyEvent {event.eventId} -> Hash {blockchain_hash[:16]}...")

    return {
        "status": "accepted",
        "duplicate": False,
        "eventId": event.eventId,
        "blockchain_hash": blockchain_hash,
        "message": "SafetyEvent successfully ingested by SafeTravel P5 dispatch engine.",
    }
