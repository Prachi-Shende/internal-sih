# pipeline/crime_cleaner.py
"""
Crime data cleaning and validation module.
Drops invalid/incomplete records and normalises field types before hotspot scoring.
"""
from datetime import datetime, timezone
from typing import List, Dict, Optional

# Default Mumbai bounding box
MUMBAI_LAT_MIN = 18.8
MUMBAI_LAT_MAX = 19.3
MUMBAI_LON_MIN = 72.7
MUMBAI_LON_MAX = 73.1

VALID_SEVERITIES = {1, 2, 3, 4, 5}


def _parse_date(value) -> Optional[datetime]:
    """Try to parse a date string into a UTC-aware datetime. Returns None on failure."""
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    if not isinstance(value, str):
        return None
    value = value.strip()
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%SZ", "%d/%m/%Y"):
        try:
            dt = datetime.strptime(value, fmt)
            return dt.replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def clean(records: List[Dict]) -> List[Dict]:
    """
    Clean and validate raw crime records.

    Rules applied:
    - Drop records with missing or non-numeric lat/lon
    - Drop records where lat ∉ [-90, 90] or lon ∉ [-180, 180]
    - Drop records where severity ∉ {1, 2, 3, 4, 5}
    - Parse date strings to datetime objects (None if unparseable)
    - Normalise crime_type to lowercase
    """
    cleaned = []
    for r in records:
        # --- lat/lon presence and type ---
        try:
            lat = float(r.get("lat") or "")
            lon = float(r.get("lon") or "")
        except (ValueError, TypeError):
            continue

        # --- lat/lon range validation ---
        if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
            continue

        # --- severity validation ---
        try:
            severity = int(float(str(r.get("severity", "")).strip()))
        except (ValueError, TypeError):
            continue
        if severity not in VALID_SEVERITIES:
            continue

        # --- date parsing ---
        date_val = _parse_date(r.get("date"))

        # --- normalise crime_type ---
        crime_type = str(r.get("crime_type", "unknown")).strip().lower()

        cleaned.append({
            "lat": lat,
            "lon": lon,
            "crime_type": crime_type,
            "date": date_val,
            "severity": severity,
            "source": str(r.get("source", "unknown")).strip()
        })

    return cleaned


def filter_to_region(
    records: List[Dict],
    min_lat: float = MUMBAI_LAT_MIN,
    max_lat: float = MUMBAI_LAT_MAX,
    min_lon: float = MUMBAI_LON_MIN,
    max_lon: float = MUMBAI_LON_MAX,
) -> List[Dict]:
    """
    Filter records to a geographic bounding box.
    Default is the Mumbai region.
    """
    return [
        r for r in records
        if min_lat <= r["lat"] <= max_lat and min_lon <= r["lon"] <= max_lon
    ]
