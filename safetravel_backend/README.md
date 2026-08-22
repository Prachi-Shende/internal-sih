# SafeTravel Backend — P5

**Central FastAPI backend for the SafeTravel Tourist Safety System.**
Built for Smart India Hackathon 2026.

---

## Quick Start

```bash
# 1. Navigate into the project
cd safetravel_backend

# 2. Install dependencies
pip install -r requirements.txt

# 3. Generate sample crime data (first time only)
python generate_sample_crimes.py

# 4. Start the server (auto-seeds DB on first run)
uvicorn main:app --reload --port 8000
```

The server auto-seeds:
- **24 safe locations** (police, hospitals, hotels, railway, tourist centres) from `data/safe_locations.json`
- **250+ crime records** processed through the pipeline to generate hotspots from `data/sample_crimes.csv`

---

## API Documentation

- **Interactive (Swagger UI):** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc
- **Health check:** http://localhost:8000/status

---

## Endpoint Reference

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Root info |
| GET | `/status` | System health (DB counts) |
| GET | `/unified-state?session_id=` | Full dashboard state for P6 |
| POST | `/location` | Save location estimate (P1) |
| GET | `/location/latest?session_id=` | Latest location for session |
| GET | `/hotspots` | All hotspots (filterable) |
| POST | `/hotspots/upload` | Upload crimes → run pipeline |
| GET | `/safe-locations` | Safe locations (proximity-sorted) |
| POST | `/safe-locations` | Add a safe location |
| POST | `/risk` | Save risk assessment (P3) |
| GET | `/risk/latest?session_id=` | Latest risk for session |
| POST | `/incident` | Create incident (I Feel Unsafe) |
| POST | `/incident/{id}/event` | Append timeline event |
| POST | `/incident/{id}/resolve` | Resolve incident |
| GET | `/incident/{id}` | Full incident + timeline |
| GET | `/incidents` | List all incidents |
| POST | `/sync` | Process P4's offline event queue |

---

## Hotspot Query Parameters

```
GET /hotspots?risk_level=HIGH
GET /hotspots?lat=19.07&lon=72.88&radius_m=500
GET /hotspots?risk_level=MEDIUM&lat=19.07&lon=72.88&radius_m=1000
```

---

## Unified State Object

The `/unified-state` endpoint returns this **locked** shape (don't rename fields):

```json
{
  "lat": 19.0760,
  "lon": 72.8777,
  "confidence": 0.71,
  "source": "PDR",
  "risk": "HIGH",
  "score": 78,
  "hotspot_id": "H1",
  "reported_incidents": 12,
  "internet": false,
  "sms": false,
  "relay": true,
  "selected_channel": "RELAY",
  "nearest_safe_location": {
    "name": "St. George's Hospital",
    "distance_m": 280,
    "type": "hospital"
  }
}
```

---

## Offline Sync (P4)

When connectivity returns, P4 sends a batch of queued events:

```json
POST /sync
{
  "session_id": "tourist-abc",
  "synced_at": "2026-08-22T14:30:00Z",
  "queued_events": [
    {"type": "location", "lat": 19.07, "lon": 72.88, "source": "PDR", "confidence": 0.6},
    {"type": "risk", "risk_level": "HIGH", "score": 75, "reasons": ["offline"]},
    {"type": "incident_event", "incident_id": "INC-123", "event_type": "NETWORK_RESTORED", "description": "Back online"},
    {"type": "communication", "incident_id": "INC-123", "internet": true, "sms": true, "relay": false, "selected_channel": "INTERNET"}
  ]
}
```

Each event is processed individually — if one fails, the rest continue.

---

## Crime Data Pipeline

The pipeline processes raw crime data into geographic hotspot scores:

1. **Ingest** — CSV / JSON / in-memory list
2. **Clean** — Drop invalid coordinates, severity, parse dates
3. **Filter** — Mumbai bounding box (lat 18.8–19.3, lon 72.7–73.1)
4. **Cell Cluster** — 300m grid cells (`cell = round(coord / 0.0027) * 0.0027`)
5. **Score** — `score = (incidents × 1.0) + (avg_severity × 2.0) + (recent × 1.5)`
6. **Risk Level** — `score ≥ 20 → HIGH`, `≥ 10 → MEDIUM`, `< 10 → LOW`
7. **Store** — Upsert hotspots table

---

## Running Tests

```bash
# Run all tests
pytest tests/ -v

# Run a specific test file
pytest tests/test_pipeline.py -v

# Run with coverage
pytest tests/ -v --tb=short
```

---

## Project Structure

```
safetravel_backend/
├── main.py                  ← App entry + startup seeding
├── database.py              ← SQLAlchemy engine + session
├── models.py                ← 8 ORM table definitions
├── schemas.py               ← Pydantic contracts (team API spec)
├── requirements.txt
├── .env.example
├── generate_sample_crimes.py
│
├── routers/
│   ├── location.py          ← POST /location, GET /location/latest
│   ├── hotspots.py          ← GET /hotspots, POST /hotspots/upload
│   ├── safe_locations.py    ← GET/POST /safe-locations
│   ├── risk.py              ← POST /risk, GET /risk/latest
│   ├── incidents.py         ← Full incident lifecycle
│   ├── sync.py              ← POST /sync (offline queue)
│   └── status.py            ← GET /status, GET /unified-state
│
├── pipeline/
│   ├── crime_ingestion.py   ← Load CSV/JSON
│   ├── crime_cleaner.py     ← Validate & normalise
│   ├── hotspot_engine.py    ← Cell clustering + scoring
│   └── pipeline_runner.py   ← Orchestrate end-to-end
│
├── data/
│   ├── safe_locations.json  ← 24 Mumbai safe locations
│   └── sample_crimes.csv    ← 250+ crime records (generated)
│
└── tests/
    ├── conftest.py
    ├── test_location.py
    ├── test_hotspots.py
    ├── test_risk.py
    ├── test_incidents.py
    ├── test_sync.py
    └── test_pipeline.py
```

---

## Team Interfaces

| Team Member | What they send to P5 | What they read from P5 |
|---|---|---|
| P1 (Prachi) | `POST /location` with `LocationEstimate` | — |
| P2 | `POST /hotspots/upload` | `GET /hotspots` |
| P3 | `POST /risk` with `RiskAssessmentCreate` | `GET /hotspots`, `GET /safe-locations` |
| P4 | `POST /incident/{id}/event`, `POST /sync` | — |
| P6 (UI) | `POST /incident` | `GET /unified-state`, `GET /incidents`, `GET /incident/{id}` |

---

## Important Rules

1. **Never say "crime rate"** — use `reported_incidents`
2. **confidence is always float 0.0–1.0** — never a % string
3. **`/unified-state` shape is locked** — field names cannot change
4. **`/sync` never rejects a whole batch** — per-event try/except
5. **All timestamps in UTC ISO 8601** — `2026-08-22T14:30:00Z`
6. **CORS is open** — `allow_origins=["*"]` during development
7. **Distance uses Haversine formula** — not Euclidean

---

*SafeTravel — Built for SIH 2026 by Team P5*
