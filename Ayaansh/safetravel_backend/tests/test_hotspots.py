# tests/test_hotspots.py
"""Tests for GET /hotspots and POST /hotspots/upload."""


SAMPLE_CRIMES = [
    {"lat": 19.076, "lon": 72.877, "crime_type": "theft",    "date": "2026-07-01", "severity": 4, "source": "test"},
    {"lat": 19.076, "lon": 72.877, "crime_type": "assault",  "date": "2026-07-02", "severity": 5, "source": "test"},
    {"lat": 19.076, "lon": 72.877, "crime_type": "robbery",  "date": "2026-07-03", "severity": 5, "source": "test"},
    {"lat": 19.076, "lon": 72.877, "crime_type": "theft",    "date": "2026-07-04", "severity": 4, "source": "test"},
    {"lat": 19.076, "lon": 72.877, "crime_type": "assault",  "date": "2026-07-05", "severity": 5, "source": "test"},
    # Different cell
    {"lat": 18.960, "lon": 72.820, "crime_type": "vandalism","date": "2026-06-01", "severity": 2, "source": "test"},
    {"lat": 18.960, "lon": 72.820, "crime_type": "harassment","date":"2026-06-15", "severity": 1, "source": "test"},
]


def _seed_hotspots(client):
    """Upload sample crimes to trigger pipeline and generate hotspots."""
    return client.post("/hotspots/upload", json=SAMPLE_CRIMES)


def test_get_hotspots_returns_list(client):
    """GET /hotspots → 200 with hotspots list structure."""
    _seed_hotspots(client)
    response = client.get("/hotspots")
    assert response.status_code == 200
    data = response.json()
    assert "hotspots" in data
    assert "total" in data
    assert isinstance(data["hotspots"], list)


def test_get_hotspots_filter_by_risk_level(client):
    """GET /hotspots?risk_level=HIGH → only HIGH hotspots returned."""
    _seed_hotspots(client)
    response = client.get("/hotspots?risk_level=HIGH")
    assert response.status_code == 200
    data = response.json()
    for hs in data["hotspots"]:
        assert hs["risk_level"] == "HIGH"


def test_get_hotspots_filter_by_risk_level_medium(client):
    """GET /hotspots?risk_level=MEDIUM → only MEDIUM hotspots."""
    _seed_hotspots(client)
    response = client.get("/hotspots?risk_level=MEDIUM")
    assert response.status_code == 200
    for hs in response.json()["hotspots"]:
        assert hs["risk_level"] == "MEDIUM"


def test_get_hotspots_proximity_filter(client):
    """GET /hotspots?lat=&lon=&radius_m= → only hotspots within radius."""
    _seed_hotspots(client)
    # 500m around the seeded cluster at 19.076, 72.877
    response = client.get("/hotspots?lat=19.076&lon=72.877&radius_m=500")
    assert response.status_code == 200
    data = response.json()
    # Should contain the nearby hotspot
    assert data["total"] >= 1


def test_upload_crimes_generates_hotspots(client):
    """POST /hotspots/upload with 50 crime records → hotspots generated."""
    crimes = []
    for i in range(50):
        crimes.append({
            "lat": 19.050 + (i % 5) * 0.003,
            "lon": 72.850 + (i % 3) * 0.003,
            "crime_type": "theft",
            "date": "2026-08-01",
            "severity": 3,
            "source": "test"
        })
    response = client.post("/hotspots/upload", json=crimes)
    assert response.status_code == 200
    data = response.json()
    assert data["hotspots_generated"] >= 1
    assert data["crimes_processed"] >= 1
