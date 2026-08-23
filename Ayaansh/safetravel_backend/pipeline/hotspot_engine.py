# pipeline/hotspot_engine.py
"""
Hotspot Engine — core geographic cell-clustering and risk scoring algorithm.

Algorithm:
  1. Cell size = 300m ≈ 0.0027 degrees lat/lon
  2. Each crime record is assigned to a cell: cell = round(coord / cell_size) * cell_size
  3. Records are grouped by (cell_lat, cell_lon)
  4. Each cell is scored:
       score = (num_incidents × 1.0) + (avg_severity × 2.0) + (recent_incidents × 1.5)
       where recent = incidents in the last 30 days
  5. Risk level assigned: score ≥ 20 → HIGH, ≥ 10 → MEDIUM, < 10 → LOW
  6. Hotspot ID = "H{index}"
"""
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Tuple

CELL_SIZE = 0.0027  # ~300m in degrees
RECENT_DAYS = 30


def assign_to_cells(records: List[Dict], cell_size: float = CELL_SIZE) -> Dict[Tuple, List[Dict]]:
    """Group crime records into geographic grid cells."""
    cells: Dict[Tuple, List[Dict]] = {}
    for record in records:
        cell_lat = round(round(record["lat"] / cell_size) * cell_size, 7)
        cell_lon = round(round(record["lon"] / cell_size) * cell_size, 7)
        key = (cell_lat, cell_lon)
        if key not in cells:
            cells[key] = []
        cells[key].append(record)
    return cells


def _count_recent(cell_records: List[Dict]) -> int:
    """Count incidents within the last RECENT_DAYS days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=RECENT_DAYS)
    count = 0
    for r in cell_records:
        date = r.get("date")
        if date is None:
            continue
        if isinstance(date, str):
            try:
                date = datetime.fromisoformat(date.replace("Z", "+00:00"))
            except ValueError:
                continue
        # Ensure timezone-aware
        if date.tzinfo is None:
            date = date.replace(tzinfo=timezone.utc)
        if date >= cutoff:
            count += 1
    return count


def calculate_score(cell_records: List[Dict]) -> float:
    """
    Hotspot score formula:
      score = (num_incidents × 1.0) + (avg_severity × 2.0) + (recent_incidents × 1.5)
    """
    n = len(cell_records)
    if n == 0:
        return 0.0
    avg_severity = sum(r["severity"] for r in cell_records) / n
    recent = _count_recent(cell_records)
    return (n * 1.0) + (avg_severity * 2.0) + (recent * 1.5)


def assign_risk_level(score: float) -> str:
    """Map score to risk level."""
    if score >= 20:
        return "HIGH"
    elif score >= 10:
        return "MEDIUM"
    return "LOW"


def generate_hotspots(records: List[Dict]) -> List[Dict]:
    """
    Full hotspot generation pipeline:
    1. Assign records to 300m cells
    2. Score each cell
    3. Assign risk level
    4. Return hotspot list sorted by score descending
    """
    cells = assign_to_cells(records)
    hotspots = []

    for idx, ((cell_lat, cell_lon), cell_records) in enumerate(cells.items()):
        score = calculate_score(cell_records)
        risk_level = assign_risk_level(score)
        recent = _count_recent(cell_records)

        hotspots.append({
            "id": f"H{idx + 1}",
            "center_lat": cell_lat,
            "center_lon": cell_lon,
            "radius_m": 300,
            "risk_level": risk_level,
            "reported_incidents": len(cell_records),
            "recent_incidents": recent,
            "hotspot_score": round(score, 2),
        })

    # Sort by score descending so H1 is the most dangerous
    hotspots.sort(key=lambda h: h["hotspot_score"], reverse=True)
    # Re-number after sorting
    for idx, h in enumerate(hotspots):
        h["id"] = f"H{idx + 1}"

    return hotspots
