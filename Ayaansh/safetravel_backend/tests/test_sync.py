# tests/test_sync.py
"""Tests for POST /sync — offline queue replay."""
import time


def _make_incident_id():
    return f"INC-{int(time.time() * 1000)}"


def test_sync_mixed_event_queue(client):
    """POST /sync with mixed event queue → all valid events processed."""
    # First create an incident to attach events to
    inc_resp = client.post("/incident", json={
        "session_id": "sync-test-session",
        "risk_level": "MEDIUM",
        "lat": 19.07,
        "lon": 72.88,
        "location_source": "GPS",
        "location_confidence": 0.9,
    })
    inc_id = inc_resp.json()["id"]

    payload = {
        "session_id": "sync-test-session",
        "synced_at": "2026-08-22T18:00:00Z",
        "queued_events": [
            {
                "type": "location",
                "lat": 19.07,
                "lon": 72.88,
                "source": "PDR",
                "confidence": 0.6,
            },
            {
                "type": "risk",
                "risk_level": "HIGH",
                "score": 75,
                "reasons": ["Queued — offline mode"],
            },
            {
                "type": "incident_event",
                "incident_id": inc_id,
                "event_type": "NETWORK_RESTORED",
                "description": "Connectivity restored after offline period.",
            },
            {
                "type": "communication",
                "incident_id": inc_id,
                "internet": False,
                "sms": True,
                "relay": False,
                "selected_channel": "SMS",
            },
        ],
    }
    response = client.post("/sync", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["processed"] == 4
    assert data["failed"] == 0


def test_sync_with_invalid_events_partial_success(client):
    """POST /sync with some invalid events → partial success, errors reported."""
    payload = {
        "session_id": "sync-partial-session",
        "synced_at": "2026-08-22T18:05:00Z",
        "queued_events": [
            # Valid location event
            {
                "type": "location",
                "lat": 19.05,
                "lon": 72.85,
                "source": "GPS",
                "confidence": 0.8,
            },
            # Invalid — unknown type
            {
                "type": "unknown_event_type",
                "data": "garbage"
            },
            # Invalid — incident_event with missing required field
            {
                "type": "incident_event",
                # missing incident_id
                "event_type": "GPS_LOST",
                "description": "GPS lost.",
            },
        ],
    }
    response = client.post("/sync", json=payload)
    assert response.status_code == 200
    data = response.json()
    # First event should succeed, others fail
    assert data["processed"] >= 1
    assert data["failed"] >= 1
    # Batch must not be completely rejected
    assert data["processed"] + data["failed"] == 3


def test_sync_empty_queue(client):
    """POST /sync with empty queue → processed=0, no errors."""
    response = client.post("/sync", json={
        "session_id": "sync-empty",
        "synced_at": "2026-08-22T18:10:00Z",
        "queued_events": []
    })
    assert response.status_code == 200
    data = response.json()
    assert data["processed"] == 0
    assert data["failed"] == 0
