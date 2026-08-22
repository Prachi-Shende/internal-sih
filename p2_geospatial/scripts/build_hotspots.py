"""
build_hotspots.py
-----------------
Run this ONCE (or whenever the crime dataset changes) to regenerate hotspots.

Usage (from the p2_geospatial/ root):
    python scripts/build_hotspots.py

Output:
    data/hotspots_processed.json
"""

import sys
from pathlib import Path

# Make sure the core package is importable when running from the scripts/ dir
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.hotspot_engine import build_hotspots

if __name__ == "__main__":
    hotspots = build_hotspots(
        csv_path    = "data/crime_raw.csv",
        output_json = "data/hotspots_processed.json",
    )
    print(f"\nDone. {len(hotspots)} hotspots saved.")
    print("First 3 hotspots:")
    for h in hotspots[:3]:
        print(f"  {h['id']}  risk={h['risk']}  "
              f"incidents={h['reported_incidents']}  score={h['score']}")
