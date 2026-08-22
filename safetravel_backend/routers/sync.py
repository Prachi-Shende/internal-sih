# routers/sync.py
"""
Offline sync router — processes P4's queued events when connectivity returns.

Endpoint:
  POST /sync — Process a batch of queued offline events

RULE: Each event is processed individually in a try/except.
      If one fails, we continue processing the rest.
      The whole batch is NEVER rejected.

Supported event types (identified by the "type" field in each event dict):
  "location"         → saved to location_estimates
  "risk"             → saved to risk_assessments
  "incident_event"   → appended to incident_events
  "communication"    → saved to communication_events
"""
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from models import (
    LocationEstimate as LocationEstimateModel,
    RiskAssessment,
    IncidentEvent,
    CommunicationEvent,
)
from schemas import OfflineSyncPayload

router = APIRouter()


@router.post("")
def sync_offline_queue(payload: OfflineSyncPayload, db: Session = Depends(get_db)):
    """
    Process P4's offline event queue when network connectivity is restored.
    Each event is processed individually; failures don't block the rest.
    """
    successes = []
    failures = []

    for idx, event in enumerate(payload.queued_events):
        try:
            event_type = str(event.get("type", "")).strip().lower()

            if event_type == "location":
                record = LocationEstimateModel(
                    lat=float(event["lat"]),
                    lon=float(event["lon"]),
                    source=event.get("source", "PDR"),
                    confidence=float(event.get("confidence", 0.5)),
                    timestamp=datetime.now(timezone.utc),
                    session_id=payload.session_id,
                )
                db.add(record)
                db.commit()
                successes.append({"index": idx, "type": "location", "status": "saved"})

            elif event_type == "risk":
                assessment = RiskAssessment(
                    session_id=payload.session_id,
                    risk_level=event.get("risk_level", "MEDIUM"),
                    score=int(event.get("score", 50)),
                    reasons=json.dumps(event.get("reasons", [])),
                    hotspot_id=event.get("hotspot_id"),
                    timestamp=datetime.now(timezone.utc),
                )
                db.add(assessment)
                db.commit()
                successes.append({"index": idx, "type": "risk", "status": "saved"})

            elif event_type == "incident_event":
                ie = IncidentEvent(
                    incident_id=event["incident_id"],
                    timestamp=datetime.now(timezone.utc),
                    event_type=event.get("event_type", "UNKNOWN"),
                    description=event.get("description", "Synced from offline queue"),
                    data=json.dumps(event.get("data")) if event.get("data") else None,
                )
                db.add(ie)
                db.commit()
                successes.append({"index": idx, "type": "incident_event", "status": "appended"})

            elif event_type == "communication":
                ce = CommunicationEvent(
                    incident_id=event.get("incident_id", ""),
                    timestamp=datetime.now(timezone.utc),
                    internet=bool(event.get("internet", False)),
                    sms=bool(event.get("sms", False)),
                    relay=bool(event.get("relay", False)),
                    selected_channel=event.get("selected_channel", "OFFLINE_QUEUE"),
                )
                db.add(ce)
                db.commit()
                successes.append({"index": idx, "type": "communication", "status": "saved"})

            else:
                failures.append({
                    "index": idx,
                    "error": f"Unknown event type: '{event_type}'. Expected: location, risk, incident_event, communication",
                })

        except Exception as e:
            db.rollback()
            failures.append({"index": idx, "error": str(e)})

    return {
        "processed": len(successes),
        "failed": len(failures),
        "successes": successes,
        "failures": failures,
        "synced_at": payload.synced_at,
    }
