from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

# Test P1-style location (Prachi sends this)
print("=== Testing P1 Location Estimate ===")
resp = client.post("/location", json={
    "lat": 19.0760,
    "lon": 72.8777,
    "source": "GPS",
    "confidence": 0.9,
    "session_id": "test-p1-001"
})
print(f"POST /location: {resp.status_code}")
if resp.status_code == 201:
    data = resp.json()
    print(f"  Returns id: {'id' in data}")
    print(f"  lat: {data.get('lat')}, lon: {data.get('lon')}")
    print(f"  source: {data.get('source')}")
    print(f"  confidence: {data.get('confidence')}")
    print(f"  nearest_hotspot: {data.get('nearest_hotspot')}")

# Test P3-style risk assessment (Shipra sends this)
print("\n=== Testing P3 Risk Assessment ===")
resp = client.post("/risk", json={
    "session_id": "test-p3-001",
    "risk_level": "HIGH",
    "score": 78,
    "reasons": ["Near crime hotspot H1", "Night time", "No companion"],
    "hotspot_id": "H1"
})
print(f"POST /risk: {resp.status_code}")
if resp.status_code == 201:
    data = resp.json()
    print(f"  risk_level: {data.get('risk_level')}")
    print(f"  score: {data.get('score')}")
    print(f"  reasons: {data.get('reasons')}")
    print(f"  hotspot_id: {data.get('hotspot_id')}")
    print(f"  id: {data.get('id')}")
    print(f"  timestamp: {data.get('timestamp')}")

# Test P4-style sync (Krish sends queued events)
print("\n=== Testing P4 Sync Payload ===")
sync_payload = {
    "session_id": "test-p4-001",
    "synced_at": "2026-08-22T18:00:00Z",
    "queued_events": [
        {
            "type": "location",
            "lat": 19.07,
            "lon": 72.88,
            "source": "PDR",
            "confidence": 0.6,
        },
        {
            "type": "risk",
            "risk_level": "MEDIUM",
            "score": 45,
            "reasons": ["Queued — offline mode"],
        },
        {
            "type": "incident_event",
            "incident_id": "INC-12345",
            "event_type": "NETWORK_RESTORED",
            "description": "Connectivity restored after offline period.",
        },
        {
            "type": "communication",
            "incident_id": "INC-12345",
            "internet": False,
            "sms": True,
            "relay": False,
            "selected_channel": "SMS",
        },
    ]
}
resp = client.post("/sync", json=sync_payload)
print(f"POST /sync: {resp.status_code}")
data = resp.json()
print(f"  processed: {data.get('processed')}")
print(f"  failed: {data.get('failed')}")
print(f"  successes: {len(data.get('successes', []))}")
print(f"  failures: {len(data.get('failures', []))}")

# Test incident creation (P4 flow)
print("\n=== Testing Incident Creation (P4 flow) ===")
inc_resp = client.post("/incident", json={
    "session_id": "test-p4-inc-001",
    "risk_level": "CRITICAL",
    "lat": 18.949,
    "lon": 72.835,
    "location_source": "PDR",
    "location_confidence": 0.6,
    "blockchain_hash": "0xabcdef1234567890"
})
print(f"POST /incident: {inc_resp.status_code}")
if inc_resp.status_code == 201:
    inc_data = inc_resp.json()
    print(f"  incident_id: {inc_data.get('id')}")
    print(f"  blockchain_hash: {inc_data.get('blockchain_hash')}")
    print(f"  status: {inc_data.get('status')}")
    
    # Add event (P4 flow)
    event_resp = client.post(f"/incident/{inc_data['id']}/event", json={
        "incident_id": inc_data['id'],
        "event_type": "RELAY_USED",
        "description": "Using relay channel as fallback",
    })
    print(f"  POST /incident/{inc_data['id']}/event: {event_resp.status_code}")
    
    # Resolve incident
    resolve_resp = client.post(f"/incident/{inc_data['id']}/resolve")
    print(f"  POST /incident/{inc_data['id']}/resolve: {resolve_resp.status_code}")
    resolve_data = resolve_resp.json()
    print(f"  status: {resolve_data.get('status')}")
    print(f"  resolved_at: {resolve_data.get('resolved_at')}")
    
    # Get full timeline
    timeline_resp = client.get(f"/incident/{inc_data['id']}")
    print(f"  GET /incident/{inc_data['id']} events: {len(timeline_resp.json().get('events', []))}")

# Test unified state
print("\n=== Testing Unified Safety State ===")
# First POST a location
client.post("/location", json={
    "lat": 19.0760, 
    "lon": 72.8777, 
    "source": "GPS", 
    "confidence": 0.9, 
    "session_id": "test-unified-integration"
})
resp = client.get("/unified-state?session_id=test-unified-integration")
print(f"GET /unified-state: {resp.status_code}")
if resp.status_code == 200:
    data = resp.json()
    print(f"  lat: {data.get('lat')}")
    print(f"  lon: {data.get('lon')}")
    print(f"  confidence: {data.get('confidence')}")
    print(f"  source: {data.get('source')}")
    print(f"  risk: {data.get('risk')}")
    print(f"  score: {data.get('score')}")
    print(f"  hotspot_id: {data.get('hotspot_id')}")
    print(f"  reported_incidents: {data.get('reported_incidents')}")
    print(f"  internet: {data.get('internet')}")
    print(f"  sms: {data.get('sms')}")
    print(f"  relay: {data.get('relay')}")
    print(f"  selected_channel: {data.get('selected_channel')}")
    ns = data.get('nearest_safe_location')
    print(f"  nearest_safe_location: {ns}")