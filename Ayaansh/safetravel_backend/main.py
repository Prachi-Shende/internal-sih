# main.py
"""
SafeTravel Backend — FastAPI Application Entry Point
P5: Central Backend for Tourist Safety System

Startup sequence:
  1. Create all DB tables
  2. Seed safe_locations from data/safe_locations.json (if table empty)
  3. Run crime pipeline on data/sample_crimes.csv (if hotspots table empty)
  → Server is demo-ready immediately after `uvicorn main:app --reload`
"""
import json
import os
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import engine, Base, SessionLocal
from routers import location, hotspots, safe_locations, risk, incidents, sync, status, report

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("safetravel")

# Absolute path to data directory (works regardless of cwd)
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
SAFE_LOCATIONS_FILE = os.path.join(DATA_DIR, "safe_locations.json")
SAMPLE_CRIMES_FILE = os.path.join(DATA_DIR, "sample_crimes.csv")


def seed_safe_locations(db):
    """Seed safe_locations from JSON file if table is empty."""
    from models import SafeLocation
    count = db.query(SafeLocation).count()
    if count > 0:
        logger.info(f"Safe locations already seeded ({count} records). Skipping.")
        return

    if not os.path.exists(SAFE_LOCATIONS_FILE):
        logger.warning(f"Safe locations file not found: {SAFE_LOCATIONS_FILE}")
        return

    with open(SAFE_LOCATIONS_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    for item in data:
        loc = SafeLocation(
            name=item["name"],
            latitude=item["latitude"],
            longitude=item["longitude"],
            type=item["type"].lower(),
            availability=item.get("availability", "unknown"),
            phone=item.get("phone"),
        )
        db.add(loc)
    db.commit()
    logger.info(f"Seeded {len(data)} safe locations from {SAFE_LOCATIONS_FILE}")


def seed_hotspots(db):
    """Run crime pipeline on sample CSV if hotspots table is empty."""
    from models import Hotspot
    from pipeline.pipeline_runner import run_full_pipeline

    count = db.query(Hotspot).count()
    if count > 0:
        logger.info(f"Hotspots already seeded ({count} records). Skipping.")
        return

    if not os.path.exists(SAMPLE_CRIMES_FILE):
        logger.warning(f"Sample crimes file not found: {SAMPLE_CRIMES_FILE}")
        logger.info("Tip: Run `python generate_sample_crimes.py` to create sample data.")
        return

    logger.info("Running crime data pipeline on sample_crimes.csv …")
    result = run_full_pipeline(SAMPLE_CRIMES_FILE, db)
    logger.info(
        f"Pipeline complete: {result['crimes_processed']} crimes → "
        f"{result['hotspots_generated']} hotspots "
        f"({result['high_risk_count']} HIGH risk)"
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan — startup and shutdown events."""
    # ── Startup ──────────────────────────────────────────────────────────────
    logger.info("SafeTravel backend starting up …")

    # Create all tables
    Base.metadata.create_all(bind=engine)
    logger.info("Database tables created (or already exist).")

    # Seed data
    db = SessionLocal()
    try:
        seed_safe_locations(db)
        seed_hotspots(db)
    finally:
        db.close()

    logger.info("SafeTravel backend ready. Docs: http://localhost:8000/docs")
    yield
    # ── Shutdown ─────────────────────────────────────────────────────────────
    logger.info("SafeTravel backend shutting down.")


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="SafeTravel Backend API",
    description=(
        "P5 — Central backend for the SafeTravel Tourist Safety System.\n\n"
        "Handles location tracking, crime hotspot data, risk assessments, "
        "incident management, offline sync, and the unified safety state."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS — open for team development ─────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(location.router,       prefix="/location",       tags=["Location (P1)"])
app.include_router(hotspots.router,       prefix="/hotspots",       tags=["Hotspots (P2)"])
app.include_router(safe_locations.router, prefix="/safe-locations", tags=["Safe Locations"])
app.include_router(risk.router,           prefix="/risk",           tags=["Risk (P3)"])
app.include_router(incidents.router,      prefix="/incident",       tags=["Incidents"])
app.include_router(sync.router,           prefix="/sync",           tags=["Offline Sync (P4)"])
app.include_router(report.router,         prefix="/report",         tags=["Reports & PDF Export"])
app.include_router(status.router,                                   tags=["Status & Unified State"])


@app.get("/", tags=["Root"])
def root():
    return {
        "project": "SafeTravel",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "/status",
    }
