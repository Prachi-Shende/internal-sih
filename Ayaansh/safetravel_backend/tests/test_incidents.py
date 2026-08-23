# tests/test_incidents.py
"""Tests for the full incident lifecycle."""
import uuid


def _create_incident(client, session_id="inc-test-session"):
    return client.post("/incident", json={
        "session_id": session_id,
        "risk_level": "HIGH",
        "lat": 19.076,
        "lon": 72.877,
        "location_source": "GPS",
        "location_confidence": 0.87
    })


def test_create_incident(client):
    """POST /incident → created with ACTIVE status and INC- prefixed ID."""
    response = _create_incident(client)
    assert response.status_code == 201
    data = response.json()
    assert data["id"].startswith("INC-")
    assert data["status"] == "ACTIVE"
    assert "started_at" in data
    assert data["resolved_at"] is None


def test_create_incident_with_blockchain_hash(client):
    """POST /incident with blockchain_hash → stored correctly."""
    response = client.post("/incident", json={
        "session_id": "inc-blockchain-test",
        "risk_level": "CRITICAL",
        "lat": 18.949,
        "lon": 72.835,
        "location_source": "PDR",
        "location_confidence": 0.6,
        "blockchain_hash": "0xabcdef1234567890"
    })
    assert response.status_code == 201
    assert response.json()["blockchain_hash"] == "0xabcdef1234567890"


def test_add_event_to_incident(client):
    """POST /incident/{id}/event → event appended to timeline."""
    inc_id = _create_incident(client).json()["id"]

    response = client.post(f"/incident/{inc_id}/event", json={
        "incident_id": inc_id,
        "event_type": "GPS_LOST",
        "description": "GPS signal lost — switching to PDR.",
        "data": {"satellites": 0}
    })
    assert response.status_code == 200
    events = response.json()["events"]
    # Should have SOS_TRIGGERED (auto) + GPS_LOST
    event_types = [e["event_type"] for e in events]
    assert "GPS_LOST" in event_types


def test_resolve_incident(client):
    """POST /incident/{id}/resolve → status becomes RESOLVED."""
    inc_id = _create_incident(client).json()["id"]
    response = client.post(f"/incident/{inc_id}/resolve")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "RESOLVED"
    assert data["resolved_at"] is not None


def test_get_incident_full_timeline(client):
    """GET /incident/{id} → returns full incident with sorted event timeline."""
    inc_id = _create_incident(client).json()["id"]

    # Add multiple events
    client.post(f"/incident/{inc_id}/event", json={
        "incident_id": inc_id,
        "event_type": "PDR_ACTIVATED",
        "description": "PDR mode activated."
    })
    client.post(f"/incident/{inc_id}/event", json={
        "incident_id": inc_id,
        "event_type": "SAFE_HAVEN_SELECTED",
        "description": "Tourist selected nearest hospital."
    })

    response = client.get(f"/incident/{inc_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == inc_id
    assert len(data["events"]) >= 2
    # Events should be sorted by timestamp
    timestamps = [e["timestamp"] for e in data["events"]]
    assert timestamps == sorted(timestamps)


def test_get_incident_not_found(client):
    """GET /incident/{id} with unknown ID → 404."""
    response = client.get("/incident/INC-9999999999")
    assert response.status_code == 404


def test_list_incidents(client):
    """GET /incident/ → returns list of incidents."""
    _create_incident(client, session_id=f"list-test-{uuid.uuid4().hex[:6]}")
    response = client.get("/incident/")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
    assert len(response.json()) >= 1


def test_list_incidents_filter_by_status(client):
    """GET /incident/?status=ACTIVE → only ACTIVE incidents returned."""
    response = client.get("/incident/?status=ACTIVE")
    assert response.status_code == 200
    for inc in response.json():
        assert inc["status"] == "ACTIVE"
