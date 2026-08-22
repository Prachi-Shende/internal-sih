"""
main.py
-------
Entry point for the P2 Geospatial Intelligence microservice.

Run:
    python main.py

Or directly with uvicorn:
    uvicorn main:app --host 0.0.0.0 --port 8001 --reload
"""

import os
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import router, load_hotspots_from_disk

load_dotenv()

from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

app = FastAPI(
    title       = "SafeTravel — P2 Geospatial Intelligence",
    description = "Maps, crime hotspots, geo-fencing, and safe-location discovery.",
    version     = "1.0.0",
)

# ─── Allow P6 (frontend) running on a different port to call us ──────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins  = ["*"],   # tighten this before production
    allow_methods  = ["*"],
    allow_headers  = ["*"],
)

app.include_router(router)

# ─── Mount static folder for Map Dashboard UI ────────────────────────────────
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

@app.get("/")
def serve_ui():
    index_path = os.path.join(static_dir, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
    return {"status": "operational", "module": "P2 Geospatial Intelligence"}

@app.on_event("startup")
async def startup():
    load_hotspots_from_disk()


if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8001))
    uvicorn.run("main:app", host=host, port=port, reload=True)
