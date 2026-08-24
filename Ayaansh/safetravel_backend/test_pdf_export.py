# test_pdf_export.py
"""
Test script for SafeTravel PDF export endpoint and data verification.
"""
from fastapi.testclient import TestClient
from main import app
import os

client = TestClient(app)

def test_pdf_export():
    print("=== Testing SafeTravel PDF Export Endpoint ===")
    
    # 1. Post a sample location
    loc_resp = client.post("/location", json={
        "lat": 19.0760,
        "lon": 72.8777,
        "source": "GPS",
        "confidence": 0.95,
        "session_id": "test-pdf-session-999"
    })
    print(f"1. POST /location: {loc_resp.status_code}")
    
    # 2. Post a sample risk assessment
    risk_resp = client.post("/risk", json={
        "session_id": "test-pdf-session-999",
        "risk_level": "LOW",
        "score": 15,
        "reasons": ["Daylight hours", "Police station nearby", "Low crime density"],
        "hotspot_id": None
    })
    print(f"2. POST /risk: {risk_resp.status_code}")

    # 3. Post a sample incident
    inc_resp = client.post("/incident", json={
        "session_id": "test-pdf-session-999",
        "risk_level": "HIGH",
        "lat": 19.0760,
        "lon": 72.8777,
        "location_source": "GPS",
        "location_confidence": 0.9,
        "blockchain_hash": "0x4a8f9c2d1e0b5a7e9f8c6b4a2d0e1f3a5b7c9e0f"
    })
    print(f"3. POST /incident: {inc_resp.status_code}")

    # 4. Request the PDF report
    pdf_resp = client.get("/report/pdf?session_id=test-pdf-session-999&user_name=Explorer%20Test&user_email=explorer@travara.app")
    print(f"4. GET /report/pdf: {pdf_resp.status_code}")
    assert pdf_resp.status_code == 200, f"Expected 200, got {pdf_resp.status_code}"
    assert pdf_resp.headers.get("content-type") == "application/pdf"
    
    pdf_bytes = pdf_resp.content
    assert pdf_bytes.startswith(b"%PDF-1.4"), "Invalid PDF header"
    assert pdf_bytes.strip().endswith(b"%%EOF"), "Invalid PDF trailer"
    
    # Check that data is embedded in the PDF byte stream
    assert b"TRAVARA" in pdf_bytes
    assert b"Explorer Test" in pdf_bytes
    assert b"19.0760" in pdf_bytes
    assert b"0x4a8f9c2d1e0b5a7e9f8c6b4a2d0e1f3a5b7c9e0f" in pdf_bytes
    
    output_path = "safetravel_verified_report.pdf"
    with open(output_path, "wb") as f:
        f.write(pdf_bytes)
    
    print(f"5. Verification Successful: PDF size is {len(pdf_bytes)} bytes.")
    print(f"   Saved PDF to: {os.path.abspath(output_path)}")
    print("=== All PDF Checks Passed! ===")

if __name__ == "__main__":
    test_pdf_export()
