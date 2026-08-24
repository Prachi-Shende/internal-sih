# test_full_suite.py
"""
Complete Verification Suite for SafeTravel FastAPI Backend.
Tests all routes and features including PDF generation, risk calculation, and real-time state.
"""
import time
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def run_tests():
    print("\n" + "="*60)
    print("      SAFETRAVEL FASTAPI FULL VERIFICATION SUITE")
    print("="*60)
    
    # 1. Root & Docs
    r = client.get("/")
    assert r.status_code == 200, f"Root failed: {r.status_code}"
    print("[PASS] 1. GET  /               -> 200 OK")
    
    r = client.get("/docs")
    assert r.status_code == 200, f"Docs failed: {r.status_code}"
    print("[PASS] 2. GET  /docs           -> 200 OK (Swagger UI Available)")
    
    # 2. Location
    r = client.post("/location", json={
        "lat": 19.0760,
        "lon": 72.8777,
        "source": "GPS",
        "confidence": 0.95,
        "session_id": "session-live-device-v2303"
    })
    assert r.status_code == 201, f"Location POST failed: {r.status_code}"
    print("[PASS] 3. POST /location       -> 201 Created")
    
    r = client.get("/location/latest?session_id=session-live-device-v2303")
    assert r.status_code == 200, f"Location GET failed: {r.status_code}"
    print("[PASS] 4. GET  /location/latest -> 200 OK")

    # 3. Hotspots & Safe Locations
    r = client.get("/hotspots")
    assert r.status_code == 200, f"Hotspots GET failed: {r.status_code}"
    print("[PASS] 5. GET  /hotspots       -> 200 OK")
    
    r = client.get("/safe-locations")
    assert r.status_code == 200, f"Safe Locations GET failed: {r.status_code}"
    print("[PASS] 6. GET  /safe-locations -> 200 OK")

    # 4. Risk Assessment
    r = client.post("/risk", json={
        "session_id": "session-live-device-v2303",
        "risk_level": "LOW",
        "score": 10,
        "reasons": ["Well-lit arterial road", "Police patrol within 200m"],
        "hotspot_id": None
    })
    assert r.status_code == 201, f"Risk POST failed: {r.status_code}"
    print("[PASS] 7. POST /risk           -> 201 Created")

    # 5. Incident & Timeline
    r = client.post("/incident", json={
        "session_id": "session-live-device-v2303",
        "risk_level": "HIGH",
        "lat": 19.0760,
        "lon": 72.8777,
        "location_source": "GPS",
        "location_confidence": 0.95,
        "blockchain_hash": "0xabc123456789deadbeef"
    })
    assert r.status_code == 201, f"Incident POST failed: {r.status_code}"
    inc_data = r.json()
    inc_id = inc_data["id"]
    print(f"[PASS] 8. POST /incident       -> 201 Created (ID: {inc_id})")


    # 6. Unified State
    r = client.get("/unified-state?session_id=session-live-device-v2303")
    assert r.status_code == 200, f"Unified State failed: {r.status_code}"
    print("[PASS] 9. GET  /unified-state  -> 200 OK")

    # 7. PDF Report Export
    r = client.get("/report/pdf?session_id=session-live-device-v2303&user_name=Explorer%20Device&user_email=explorer@travara.app")
    assert r.status_code == 200, f"PDF export failed: {r.status_code}"
    assert r.headers.get("content-type") == "application/pdf"
    assert r.content.startswith(b"%PDF-1.4")
    print(f"[PASS] 10. GET /report/pdf     -> 200 OK ({len(r.content)} bytes valid PDF-1.4)")

    # 8. P1 SafetyEvent Contract Ingestion
    test_event_id = f"SOS-TEST-{int(time.time()*1000)}"
    r = client.post("/api/safety-events", json={
        "eventId": test_event_id,
        "eventType": "sos",
        "timestamp": "2026-08-24T12:00:00.000Z",
        "latitude": 19.0760,
        "longitude": 72.8777,
        "positionSource": "gps",
        "confidence": 0.96,
        "uncertaintyMeters": 3.8,
        "positioningMode": "gps",
        "gpsHealth": "active",
        "internetAvailable": True,
        "eventStatus": "sent",
        "deliveryChannel": "HTTP",
        "metadata": {"session_id": "session-live-device-v2303"}
    })
    assert r.status_code == 201, f"SafetyEvent POST failed: {r.status_code}"
    print("[PASS] 11. POST /api/safety-events -> 201 Created (P1 Contract Ingestion)")

    # Idempotent duplicate check
    r_dup = client.post("/api/safety-events", json={
        "eventId": test_event_id,
        "eventType": "sos",
        "metadata": {"session_id": "session-live-device-v2303"}
    })
    assert r_dup.status_code == 200, f"Duplicate SafetyEvent expected 200, got {r_dup.status_code}"
    assert r_dup.json().get("duplicate") is True
    print("[PASS] 12. POST /api/safety-events (duplicate) -> 200 OK (Idempotency Verified)")

    # 9. Status
    r = client.get("/status")
    assert r.status_code == 200, f"Status failed: {r.status_code}"
    print("[PASS] 13. GET  /status        -> 200 OK")

    print("="*60)
    print("      ALL 13 BACKEND API VERIFICATIONS PASSED 100%!")
    print("="*60 + "\n")

if __name__ == "__main__":
    run_tests()

