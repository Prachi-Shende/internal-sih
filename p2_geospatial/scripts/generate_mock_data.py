"""
generate_mock_data.py
---------------------
Run this ONCE to create data/crime_raw.csv before running build_hotspots.py.

Usage:
    python scripts/generate_mock_data.py

Output:
    data/crime_raw.csv  (1000 synthetic crime records over Mumbai)
"""

import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta
from pathlib import Path

# ─── Mumbai approximate bounding box ─────────────────────────────────────────
LAT_MIN, LAT_MAX = 19.00, 19.20
LON_MIN, LON_MAX = 72.75, 72.95

# ─── Crime type → base severity (1=low, 4=critical) ─────────────────────────
CRIME_TYPES = {
    "Theft":        1,
    "Harassment":   2,
    "Robbery":      3,
    "Assault":      4,
}

# ─── Hotspot seeds: we cluster crimes around specific coords to make the map
#     interesting rather than a random scatter ──────────────────────────────
HOTSPOT_SEEDS = [
    (19.075, 72.877),   # Churchgate area
    (19.100, 72.865),   # Bandra
    (19.045, 72.855),   # Colaba
    (19.130, 72.900),   # Kurla
    (19.060, 72.836),   # Worli
]


def generate_crime_records(n: int = 1000) -> pd.DataFrame:
    records = []
    for i in range(n):
        # 60% of crimes cluster near the seeds, 40% are random
        if random.random() < 0.60:
            seed_lat, seed_lon = random.choice(HOTSPOT_SEEDS)
            lat = np.random.normal(seed_lat, 0.008)   # ~800m std dev
            lon = np.random.normal(seed_lon, 0.008)
            # Clip to Mumbai bounds
            lat = float(np.clip(lat, LAT_MIN, LAT_MAX))
            lon = float(np.clip(lon, LON_MIN, LON_MAX))
        else:
            lat = float(np.random.uniform(LAT_MIN, LAT_MAX))
            lon = float(np.random.uniform(LON_MIN, LON_MAX))

        ctype    = random.choice(list(CRIME_TYPES.keys()))
        severity = CRIME_TYPES[ctype]
        days_ago = np.random.randint(0, 730)   # up to 2 years ago
        date     = (datetime.now() - timedelta(days=int(days_ago))).strftime("%Y-%m-%d")

        records.append({
            "latitude":   round(lat, 6),
            "longitude":  round(lon, 6),
            "crime_type": ctype,
            "date":       date,
            "severity":   severity,
        })

    return pd.DataFrame(records)


if __name__ == "__main__":
    Path("data").mkdir(exist_ok=True)
    df = generate_crime_records(1000)
    output = Path("data/crime_raw.csv")
    df.to_csv(output, index=False)
    print(f"[OK] Generated {len(df)} crime records → {output}")
    print(df.head())
