# tests/test_pipeline.py
"""
Unit tests for the crime data pipeline modules.
Tests crime_cleaner and hotspot_engine in isolation (no DB required).
"""
from datetime import datetime, timedelta, timezone

from pipeline.crime_cleaner import clean, filter_to_region
from pipeline.hotspot_engine import (
    assign_to_cells,
    calculate_score,
    assign_risk_level,
    generate_hotspots,
)


# ── crime_cleaner tests ────────────────────────────────────────────────────────

def test_clean_drops_missing_lat():
    """clean() drops records with missing lat."""
    records = [
        {"lat": None, "lon": 72.88, "crime_type": "theft", "date": "2026-07-01", "severity": 3, "source": "test"},
        {"lat": 19.07, "lon": 72.88, "crime_type": "theft", "date": "2026-07-01", "severity": 3, "source": "test"},
    ]
    result = clean(records)
    assert len(result) == 1
    assert result[0]["lat"] == 19.07


def test_clean_drops_missing_lon():
    """clean() drops records with missing lon."""
    records = [
        {"lat": 19.07, "lon": None, "crime_type": "theft", "date": "2026-07-01", "severity": 3, "source": "test"},
    ]
    assert clean(records) == []


def test_clean_drops_out_of_range_lat():
    """clean() drops records where lat not in [-90, 90]."""
    records = [
        {"lat": 95.0, "lon": 72.88, "crime_type": "theft", "date": "2026-07-01", "severity": 3, "source": "test"},
        {"lat": -91.0, "lon": 72.88, "crime_type": "theft", "date": "2026-07-01", "severity": 3, "source": "test"},
    ]
    assert clean(records) == []


def test_clean_drops_out_of_range_lon():
    """clean() drops records where lon not in [-180, 180]."""
    records = [
        {"lat": 19.07, "lon": 190.0, "crime_type": "theft", "date": "2026-07-01", "severity": 3, "source": "test"},
    ]
    assert clean(records) == []


def test_clean_drops_invalid_severity():
    """clean() drops records with severity not in {1,2,3,4,5}."""
    records = [
        {"lat": 19.07, "lon": 72.88, "crime_type": "theft", "date": "2026-07-01", "severity": 0, "source": "test"},
        {"lat": 19.07, "lon": 72.88, "crime_type": "theft", "date": "2026-07-01", "severity": 6, "source": "test"},
        {"lat": 19.07, "lon": 72.88, "crime_type": "theft", "date": "2026-07-01", "severity": 3, "source": "test"},
    ]
    result = clean(records)
    assert len(result) == 1
    assert result[0]["severity"] == 3


def test_clean_normalises_crime_type():
    """clean() normalises crime_type to lowercase."""
    records = [
        {"lat": 19.07, "lon": 72.88, "crime_type": "THEFT", "date": "2026-07-01", "severity": 2, "source": "test"},
    ]
    result = clean(records)
    assert result[0]["crime_type"] == "theft"


def test_filter_to_region_removes_out_of_box():
    """filter_to_region() removes records outside the Mumbai bounding box."""
    records = [
        {"lat": 19.07, "lon": 72.88, "crime_type": "theft", "severity": 2, "source": "test", "date": None},   # Inside
        {"lat": 28.61, "lon": 77.20, "crime_type": "theft", "severity": 2, "source": "test", "date": None},   # Delhi — outside
    ]
    result = filter_to_region(records)
    assert len(result) == 1
    assert result[0]["lat"] == 19.07


# ── hotspot_engine tests ───────────────────────────────────────────────────────

def _make_record(lat, lon, severity=3, days_ago=5):
    return {
        "lat": lat, "lon": lon,
        "crime_type": "theft",
        "severity": severity,
        "source": "test",
        "date": datetime.now(timezone.utc) - timedelta(days=days_ago),
    }


def test_assign_to_cells_clusters_nearby_crimes():
    """assign_to_cells() groups crimes within the same 300m cell."""
    records = [
        _make_record(19.0760, 72.8777),
        _make_record(19.0761, 72.8778),   # Same cell (~10m away)
        _make_record(19.0760, 72.8777),
        _make_record(19.1000, 72.9000),   # Different cell
    ]
    cells = assign_to_cells(records)
    assert len(cells) == 2
    # Largest cell has 3 records
    sizes = sorted(len(v) for v in cells.values())
    assert sizes == [1, 3]


def test_calculate_score_formula():
    """calculate_score() applies the correct formula."""
    # 5 records, severity=4, all recent → score = 5*1 + 4*2 + 5*1.5 = 5+8+7.5 = 20.5
    records = [_make_record(19.07, 72.88, severity=4, days_ago=2) for _ in range(5)]
    score = calculate_score(records)
    assert abs(score - 20.5) < 0.01


def test_assign_risk_level_high():
    """HIGH risk assigned when score >= 20."""
    assert assign_risk_level(20.0) == "HIGH"
    assert assign_risk_level(35.5) == "HIGH"


def test_assign_risk_level_medium():
    """MEDIUM risk assigned when 10 <= score < 20."""
    assert assign_risk_level(10.0) == "MEDIUM"
    assert assign_risk_level(19.9) == "MEDIUM"


def test_assign_risk_level_low():
    """LOW risk assigned when score < 10."""
    assert assign_risk_level(9.9) == "LOW"
    assert assign_risk_level(0.0) == "LOW"


def test_generate_hotspots_clusters_correctly():
    """generate_hotspots() produces correct hotspot list from clustered records."""
    # 10 crimes near same location → should form 1 HIGH cell
    records = [_make_record(19.076 + i * 0.0001, 72.877 + i * 0.0001, severity=4, days_ago=3)
               for i in range(10)]
    hotspots = generate_hotspots(records)
    assert len(hotspots) >= 1
    # The densest cluster should be HIGH risk (10 recent high-severity crimes)
    scores = [h["hotspot_score"] for h in hotspots]
    assert max(scores) >= 20


def test_generate_hotspots_returns_correct_fields():
    """generate_hotspots() returns dicts with all required fields."""
    records = [_make_record(19.07, 72.88) for _ in range(3)]
    hotspots = generate_hotspots(records)
    assert len(hotspots) >= 1
    h = hotspots[0]
    required_fields = ["id", "center_lat", "center_lon", "radius_m", "risk_level",
                       "reported_incidents", "recent_incidents", "hotspot_score"]
    for field in required_fields:
        assert field in h, f"Missing field: {field}"


def test_pipeline_high_risk_assigned_when_score_over_20():
    """HIGH risk is correctly assigned when score >= 20."""
    # 15 recent, severity-5 crimes → score = 15 + 5*2 + 15*1.5 = 15+10+22.5 = 47.5
    records = [_make_record(19.07, 72.88, severity=5, days_ago=1) for _ in range(15)]
    hotspots = generate_hotspots(records)
    assert any(h["risk_level"] == "HIGH" for h in hotspots)
