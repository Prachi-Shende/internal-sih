"""
hotspot_engine.py
-----------------
Turns a raw CSV of crime records into a list of geographic hotspot objects.

Pipeline:
  crime_raw.csv
      → load_and_clean()
      → create_grid()
      → calculate_scores()
      → classify_risk()
      → [list of Hotspot dicts]
"""

import json
import math
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

# ─── Grid resolution ─────────────────────────────────────────────────────────
# Rounding lat/lon to 3 decimal places ≈ 100 m × 100 m cell at Mumbai's latitude
GRID_PRECISION = 3

# ─── Hotspot circle radius (metres) shown on the map ─────────────────────────
HOTSPOT_RADIUS_M = 150

# ─── Recency buckets ─────────────────────────────────────────────────────────
RECENCY_LAST_30_DAYS  = 3
RECENCY_LAST_6_MONTHS = 2
RECENCY_OLDER         = 1

# ─── Risk thresholds (percentile-based) ──────────────────────────────────────
HIGH_PERCENTILE   = 85   # top 15% → HIGH
MEDIUM_PERCENTILE = 50   # next 35% → MEDIUM
                         # bottom 50% → LOW


# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Load & clean
# ─────────────────────────────────────────────────────────────────────────────

def load_and_clean(filepath: str) -> pd.DataFrame:
    """
    Load crime_raw.csv and discard unusable rows.

    Expected CSV columns:
        latitude, longitude, crime_type, date (YYYY-MM-DD), severity (int 1-4)
    """
    df = pd.read_csv(filepath)
    original_len = len(df)

    # Drop rows with missing lat/lon
    df = df.dropna(subset=["latitude", "longitude"])

    # Drop rows with obviously invalid coordinates
    df = df[
        (df["latitude"].between(-90, 90)) &
        (df["longitude"].between(-180, 180))
    ]

    # Parse date — rows with unparseable dates get NaT (we'll handle below)
    df["date"] = pd.to_datetime(df["date"], errors="coerce")
    df = df.dropna(subset=["date"])

    # Ensure severity is an integer 1–4; fill unknown with 1
    df["severity"] = pd.to_numeric(df["severity"], errors="coerce").fillna(1).astype(int)
    df["severity"] = df["severity"].clip(1, 4)

    # Normalise crime_type to uppercase
    df["crime_type"] = df["crime_type"].str.strip().str.upper()

    print(f"[clean] {original_len} raw → {len(df)} usable records")
    return df.reset_index(drop=True)


# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Snap to grid
# ─────────────────────────────────────────────────────────────────────────────

def create_grid(df: pd.DataFrame) -> pd.DataFrame:
    """
    Round lat/lon so nearby crimes collapse into the same grid cell.
    """
    df = df.copy()
    df["cell_lat"] = df["latitude"].round(GRID_PRECISION)
    df["cell_lon"] = df["longitude"].round(GRID_PRECISION)
    return df


# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Score each cell
# ─────────────────────────────────────────────────────────────────────────────

def _recency_weight(date: pd.Timestamp) -> int:
    now = datetime.now()
    delta = now - date.to_pydatetime()
    if delta <= timedelta(days=30):
        return RECENCY_LAST_30_DAYS
    if delta <= timedelta(days=180):
        return RECENCY_LAST_6_MONTHS
    return RECENCY_OLDER


def calculate_scores(df: pd.DataFrame) -> pd.DataFrame:
    """
    Aggregate crimes per grid cell and produce a composite score.

    Score = (incident_count × 1) + (avg_severity × 2) + (avg_recency × 3)

    Returns one row per cell with columns:
        cell_lat, cell_lon, incident_count, recent_count, avg_severity,
        avg_recency, score
    """
    df = df.copy()
    df["recency_weight"] = df["date"].apply(_recency_weight)

    # "Recent" = last 30 days
    cutoff = datetime.now() - timedelta(days=30)
    df["is_recent"] = df["date"] >= cutoff

    grouped = df.groupby(["cell_lat", "cell_lon"]).agg(
        incident_count  = ("severity",        "count"),
        recent_count    = ("is_recent",        "sum"),
        avg_severity    = ("severity",         "mean"),
        avg_recency     = ("recency_weight",   "mean"),
    ).reset_index()

    grouped["score"] = (
        grouped["incident_count"] * 1 +
        grouped["avg_severity"]   * 2 +
        grouped["avg_recency"]    * 3
    ).round(2)

    print(f"[score] {len(grouped)} unique grid cells produced")
    return grouped


# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Classify risk
# ─────────────────────────────────────────────────────────────────────────────

def classify_risk(df: pd.DataFrame) -> pd.DataFrame:
    """
    Assign LOW / MEDIUM / HIGH based on score percentiles.
    """
    df = df.copy()
    high_threshold   = df["score"].quantile(HIGH_PERCENTILE   / 100)
    medium_threshold = df["score"].quantile(MEDIUM_PERCENTILE / 100)

    def _label(score):
        if score >= high_threshold:
            return "HIGH"
        if score >= medium_threshold:
            return "MEDIUM"
        return "LOW"

    df["risk"] = df["score"].apply(_label)

    counts = df["risk"].value_counts().to_dict()
    print(f"[classify] HIGH={counts.get('HIGH',0)}  "
          f"MEDIUM={counts.get('MEDIUM',0)}  LOW={counts.get('LOW',0)}")
    return df


# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Serialise to list of hotspot dicts
# ─────────────────────────────────────────────────────────────────────────────

def to_hotspot_list(df: pd.DataFrame) -> list[dict]:
    """
    Convert the scored DataFrame into the canonical hotspot JSON format.

    Each dict:
        id, center_lat, center_lon, radius, risk, score,
        reported_incidents, recent_incidents
    """
    hotspots = []
    for i, row in enumerate(df.itertuples(), start=1):
        hotspots.append({
            "id":                  f"H{i:04d}",
            "center_lat":          float(row.cell_lat),
            "center_lon":          float(row.cell_lon),
            "radius":              HOTSPOT_RADIUS_M,
            "risk":                row.risk,
            "score":               float(row.score),
            "reported_incidents":  int(row.incident_count),
            "recent_incidents":    int(row.recent_count),
        })
    return hotspots


# ─────────────────────────────────────────────────────────────────────────────
# Public convenience function
# ─────────────────────────────────────────────────────────────────────────────

def build_hotspots(csv_path: str, output_json: str | None = None) -> list[dict]:
    """
    Run the full pipeline from CSV → hotspot list.
    Optionally save to a JSON file.
    """
    df = load_and_clean(csv_path)
    df = create_grid(df)
    df = calculate_scores(df)
    df = classify_risk(df)
    hotspots = to_hotspot_list(df)

    if output_json:
        Path(output_json).parent.mkdir(parents=True, exist_ok=True)
        with open(output_json, "w") as f:
            json.dump(hotspots, f, indent=2)
        print(f"[save] {len(hotspots)} hotspots → {output_json}")

    return hotspots
