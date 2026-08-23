# pipeline/pipeline_runner.py
"""
Orchestrates the full crime data pipeline:
  ingest → clean → filter to region → save crimes → generate hotspots → upsert hotspots

Returns a summary dict: {crimes_processed, hotspots_generated, high_risk_count}
"""
from datetime import datetime, timezone
from typing import Union, List, Dict
from sqlalchemy.orm import Session

from pipeline.crime_ingestion import load_from_csv, load_from_json, load_from_records
from pipeline.crime_cleaner import clean, filter_to_region
from pipeline.hotspot_engine import generate_hotspots


def run_full_pipeline(
    source: Union[str, List[Dict]],
    db_session: Session
) -> Dict:
    """
    Run the complete crime data pipeline.

    Args:
        source: Path to a CSV/JSON file, OR a list of raw crime dicts.
        db_session: Active SQLAlchemy session.

    Returns:
        {crimes_processed, hotspots_generated, high_risk_count}
    """
    # Import here to avoid circular dependency at module load time
    from models import CrimeIncident, Hotspot

    # ── Step 1: Ingest ──────────────────────────────────────────────────────
    if isinstance(source, str):
        if source.endswith(".csv"):
            raw = load_from_csv(source)
        elif source.endswith(".json"):
            raw = load_from_json(source)
        else:
            raise ValueError(f"Unsupported file format for source: {source}")
    elif isinstance(source, list):
        raw = load_from_records(source)
    else:
        raise TypeError(f"source must be a file path (str) or list of dicts. Got: {type(source)}")

    # ── Step 2: Clean & filter ───────────────────────────────────────────────
    cleaned = clean(raw)
    cleaned = filter_to_region(cleaned)

    if not cleaned:
        return {"crimes_processed": 0, "hotspots_generated": 0, "high_risk_count": 0}

    # ── Step 3: Save cleaned crime_incidents to DB ───────────────────────────
    for record in cleaned:
        crime = CrimeIncident(
            lat=record["lat"],
            lon=record["lon"],
            crime_type=record["crime_type"],
            date=record.get("date") or datetime.now(timezone.utc),
            severity=record["severity"],
            source=record.get("source", "unknown"),
        )
        db_session.add(crime)
    db_session.commit()

    # ── Step 4: Run hotspot engine ────────────────────────────────────────────
    hotspot_data = generate_hotspots(cleaned)

    # ── Step 5: Upsert hotspots (by generated ID) ─────────────────────────────
    # Clear existing hotspots produced by this pipeline run to avoid duplicates
    for h in hotspot_data:
        existing = db_session.query(Hotspot).filter(Hotspot.id == h["id"]).first()
        if existing:
            existing.center_lat = h["center_lat"]
            existing.center_lon = h["center_lon"]
            existing.risk_level = h["risk_level"]
            existing.reported_incidents = h["reported_incidents"]
            existing.recent_incidents = h["recent_incidents"]
            existing.hotspot_score = h["hotspot_score"]
            existing.radius_m = h["radius_m"]
        else:
            hotspot = Hotspot(
                id=h["id"],
                center_lat=h["center_lat"],
                center_lon=h["center_lon"],
                radius_m=h["radius_m"],
                risk_level=h["risk_level"],
                reported_incidents=h["reported_incidents"],
                recent_incidents=h["recent_incidents"],
                hotspot_score=h["hotspot_score"],
                created_at=datetime.now(timezone.utc),
            )
            db_session.add(hotspot)

    db_session.commit()

    high_risk_count = sum(1 for h in hotspot_data if h["risk_level"] == "HIGH")

    return {
        "crimes_processed": len(cleaned),
        "hotspots_generated": len(hotspot_data),
        "high_risk_count": high_risk_count,
    }
