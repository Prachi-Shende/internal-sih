# tests/test_risk.py
"""Tests for POST /risk and GET /risk/latest."""
import uuid


def test_post_valid_risk_assessment(client):
    """POST valid risk assessment → 201."""
    response = client.post("/risk", json={
        "session_id": "risk-sess-001",
        "risk_level": "HIGH",
        "score": 78,
        "reasons": ["Near crime hotspot H1", "Night time", "No companion"],
        "hotspot_id": "H1"
    })
    assert response.status_code == 201
    data = response.json()
    assert data["risk_level"] == "HIGH"
    assert data["score"] == 78
    assert isinstance(data["reasons"], list)
    assert "id" in data
    assert "timestamp" in data


def test_post_risk_assessment_critical(client):
    """POST CRITICAL risk assessment → 201."""
    response = client.post("/risk", json={
        "session_id": "risk-sess-002",
        "risk_level": "CRITICAL",
        "score": 95,
        "reasons": ["Active incident zone"],
    })
    assert response.status_code == 201
    assert response.json()["risk_level"] == "CRITICAL"


def test_post_risk_invalid_risk_level(client):
    """POST with invalid risk_level → 422."""
    response = client.post("/risk", json={
        "session_id": "risk-sess-003",
        "risk_level": "EXTREME",   # not in pattern
        "score": 50,
        "reasons": []
    })
    assert response.status_code == 422


def test_post_risk_score_out_of_range(client):
    """POST with score > 100 → 422."""
    response = client.post("/risk", json={
        "session_id": "risk-sess-004",
        "risk_level": "HIGH",
        "score": 150,   # max is 100
        "reasons": []
    })
    assert response.status_code == 422


def test_get_latest_risk(client):
    """GET /risk/latest → returns most recent for session."""
    session_id = f"risk-{uuid.uuid4().hex[:8]}"
    client.post("/risk", json={
        "session_id": session_id,
        "risk_level": "LOW",
        "score": 10,
        "reasons": ["Safe area"]
    })
    client.post("/risk", json={
        "session_id": session_id,
        "risk_level": "MEDIUM",
        "score": 45,
        "reasons": ["Nearby hotspot"]
    })
    response = client.get(f"/risk/latest?session_id={session_id}")
    assert response.status_code == 200
    # Should return the second (most recent) assessment
    assert response.json()["risk_level"] == "MEDIUM"
    assert response.json()["score"] == 45


def test_get_latest_risk_not_found(client):
    """GET /risk/latest with unknown session → 404."""
    response = client.get("/risk/latest?session_id=no-such-session-xyz")
    assert response.status_code == 404
