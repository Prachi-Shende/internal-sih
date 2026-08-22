from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers.sync import router as sync_router

app = FastAPI(
    title="Tourist Safety Resilience API — P4 Backend Integration",
    description="FastAPI Backend for Task P4 (Communication Resilience + Blockchain) supporting offline sync flushes and tamper-evident blockchain verification.",
    version="1.0.0"
)

# Enable CORS for Flutter mobile client app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sync_router)

@app.get("/")
async def root():
    return {
        "system": "Tourist Safety Engine — P4 Resilience Backend",
        "status": "OPERATIONAL",
        "docs_url": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    print("\n" + "="*60)
    print("🚀 Server running! Open in your browser at:")
    print("👉 http://localhost:8000/docs  OR  http://127.0.0.1:8000/docs")
    print("="*60 + "\n")
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)

