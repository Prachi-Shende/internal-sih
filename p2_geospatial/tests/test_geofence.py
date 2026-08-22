"""
test_geofence.py
----------------
Quick offline test — no running server needed.

Run from the p2_geospatial/ root:
    python tests/test_geofence.py

This simulates a user walking toward a HIGH-risk hotspot and prints
the expected state transitions: OUTSIDE → APPROACHING → INSIDE.
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.geofence_engine import check_geofence, haversine

# ─── A fake hotspot for testing ──────────────────────────────────────────────
FAKE_HOTSPOTS = [
    {
        "id":                  "H0001",
        "center_lat":          19.0760,
        "center_lon":          72.8777,
        "radius":              150,
        "risk":                "HIGH",
        "score":               84.0,
        "reported_incidents":  12,
        "recent_incidents":    4,
    },
    {
        "id":                  "H0002",
        "center_lat":          19.0820,
        "center_lon":          72.8800,
        "radius":              150,
        "risk":                "MEDIUM",
        "score":               40.0,
        "reported_incidents":  5,
        "recent_incidents":    1,
    },
]

# ─── Simulate walking from far away toward hotspot H0001 ─────────────────────
# We start 500 m north of the hotspot and step southward
WALK_STEPS = [
    # (lat,     lon,      description)
    (19.0805,  72.8777,  "~500m away  → expect OUTSIDE"),
    (19.0785,  72.8777,  "~280m away  → expect APPROACHING"),
    (19.0770,  72.8777,  "~110m away  → expect INSIDE"),
    (19.0760,  72.8777,  "0m (centre) → expect INSIDE"),
    (19.0730,  72.8777,  "~330m south → expect OUTSIDE again"),
]


def run_test():
    print("=" * 60)
    print("P2 Geo-Fence Engine — Walk Simulation")
    print("=" * 60)

    for lat, lon, description in WALK_STEPS:
        dist = haversine(lat, lon,
                         FAKE_HOTSPOTS[0]["center_lat"],
                         FAKE_HOTSPOTS[0]["center_lon"])

        event = check_geofence(lat, lon, FAKE_HOTSPOTS, location_source="PDR")

        status_icon = {
            "INSIDE":      "🔴",
            "APPROACHING": "⚠️ ",
            "OUTSIDE":     "🟢",
        }.get(event.state, "?")

        print(f"\n{description}")
        print(f"  Location: ({lat}, {lon})  |  Distance to H0001: {dist:.0f} m")
        print(f"  {status_icon} State: {event.state}  "
              f"Hotspot: {event.hotspot_id}  "
              f"Risk: {event.risk}")

    print("\n" + "=" * 60)
    print("Test complete. If states match expectations above, engine is working.")


if __name__ == "__main__":
    run_test()
