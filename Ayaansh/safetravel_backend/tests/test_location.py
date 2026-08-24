# tests/test_location.py
"""Tests for POST /location and GET /location/latest."""
import uuid


def test_post_valid_location(client):
    """POST valid location → 201, returns id."""
    response = client.post("/location", json={
        "lat": 19.0760,
        "lon": 72.8777,
        "source": "GPS",
        "confidence": 0.9,
        "session_id": "test-loc-001"
    })
    assert response.status_code == 201
    data = response.json()
    assert "id" in data
    assert data["lat"] == 19.0760
    assert data["source"] == "GPS"
    assert data["confidence"] == 0.9


def test_post_location_with_pdr_source(client):
    """POST PDR location → 201."""
    response = client.post("/location", json={
        "lat": 19.0543,
        "lon": 72.8429,
        "source": "PDR",
        "confidence": 0.65,
        "session_id": "test-loc-002"
    })
    assert response.status_code == 201
    assert response.json()["source"] == "PDR"


def test_post_location_invalid_source(client):
    """POST location with invalid source → 422 Unprocessable Entity."""
    response = client.post("/location", json={
        "lat": 19.0760,
        "lon": 72.8777,
        "source": "SATELLITE",   # Not in allowed pattern
        "confidence": 0.9
    })
    assert response.status_code == 422


def test_post_location_confidence_over_1(client):
    """POST location with confidence > 1.0 → 422."""
    response = client.post("/location", json={
        "lat": 19.0760,
        "lon": 72.8777,
        "source": "GPS",
        "confidence": 1.5    # Invalid — max is 1.0
    })
    assert response.status_code == 422


def test_post_location_confidence_negative(client):
    """POST location with confidence < 0.0 → 422."""
    response = client.post("/location", json={
        "lat": 19.0760,
        "lon": 72.8777,
        "source": "GPS",
        "confidence": -0.1
    })
    assert response.status_code == 422


def test_get_latest_location_valid_session(client):
    """GET /location/latest with valid session_id → 200."""
    session_id = f"sess-{uuid.uuid4().hex[:8]}"
    client.post("/location", json={
        "lat": 18.9489,
        "lon": 72.8353,
        "source": "GPS",
        "confidence": 0.8,
        "session_id": session_id
    })
    response = client.get(f"/location/latest?session_id={session_id}")
    assert response.status_code == 200
    assert response.json()["session_id"] == session_id


def test_get_latest_location_unknown_session(client):
    """GET /location/latest with unknown session_id → 404."""
    response = client.get("/location/latest?session_id=nonexistent-session-xyz")
    assert response.status_code == 404
