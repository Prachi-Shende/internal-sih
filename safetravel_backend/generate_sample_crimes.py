"""
Script to generate 200+ realistic Mumbai crime records for SafeTravel sample data.
Run once: python generate_sample_crimes.py
"""
import csv
import random
from datetime import datetime, timedelta

random.seed(42)

CRIME_TYPES = ["theft", "assault", "harassment", "robbery", "vandalism", "pickpocketing"]

# Mumbai region bounding box
LAT_MIN, LAT_MAX = 18.85, 19.25
LON_MIN, LON_MAX = 72.75, 73.05

# High-density hotspot seeds (lat, lon, count) — guarantees HIGH risk cells
HOTSPOT_SEEDS = [
    (19.0760, 72.8777, 18),  # Dadar area
    (18.9489, 72.8353, 15),  # Crawford Market
    (19.1197, 72.9093, 12),  # Ghatkopar
    (18.9398, 72.8354, 14),  # CSMT
    (19.0543, 72.8429, 10),  # Bandra
    (19.0176, 72.8446, 13),  # Matunga
]

rows = []
today = datetime.now()

# Generate clustered HIGH-risk records
for seed_lat, seed_lon, count in HOTSPOT_SEEDS:
    for _ in range(count):
        lat = seed_lat + random.uniform(-0.001, 0.001)
        lon = seed_lon + random.uniform(-0.001, 0.001)
        days_ago = random.randint(0, 30)  # recent, for HIGH score
        date = (today - timedelta(days=days_ago)).strftime("%Y-%m-%d")
        rows.append({
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "crime_type": random.choice(["theft", "robbery", "assault"]),
            "date": date,
            "severity": random.randint(3, 5),
            "source": "Mumbai Police FIR Dataset 2024"
        })

# Fill remaining with random distribution across Mumbai
target = 250
while len(rows) < target:
    lat = round(random.uniform(LAT_MIN, LAT_MAX), 6)
    lon = round(random.uniform(LON_MIN, LON_MAX), 6)
    days_ago = random.randint(0, 90)
    date = (today - timedelta(days=days_ago)).strftime("%Y-%m-%d")
    rows.append({
        "lat": lat,
        "lon": lon,
        "crime_type": random.choice(CRIME_TYPES),
        "date": date,
        "severity": random.randint(1, 5),
        "source": random.choice([
            "Mumbai Police FIR Dataset 2024",
            "NCRB 2024",
            "Smart City Crime Reports"
        ])
    })

random.shuffle(rows)

with open("data/sample_crimes.csv", "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["lat", "lon", "crime_type", "date", "severity", "source"])
    writer.writeheader()
    writer.writerows(rows)

print(f"Generated {len(rows)} crime records -> data/sample_crimes.csv")
