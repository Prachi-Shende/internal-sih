from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

class LocationSchema(BaseModel):
    lat: float = Field(..., description="Latitude coordinate")
    lon: float = Field(..., description="Longitude coordinate")
    source: str = Field("PDR", description="Positioning source: GPS, PDR, WIFI, LAST_KNOWN")
    confidence: float = Field(0.7, description="Location confidence score between 0.0 and 1.0")

class RiskAssessmentSchema(BaseModel):
    risk: str = Field(..., description="Risk category: LOW, MEDIUM, HIGH, CRITICAL")
    score: int = Field(..., description="Risk score between 0 and 100")
    reasons: List[str] = Field(default_factory=list, description="Contextual reasons for risk score")

class SafeHavenSchema(BaseModel):
    name: str
    distance_m: float
    lat: Optional[float] = None
    lon: Optional[float] = None

class IncidentPayloadSchema(BaseModel):
    incident_id: str
    user_id: str
    timestamp: datetime
    event_type: str = Field(..., description="SOS_TRIGGERED, RISK_ESCALATED, SAFE_HAVEN_SELECTED, INCIDENT_RESOLVED")
    location: LocationSchema
    risk_assessment: RiskAssessmentSchema
    safe_haven: Optional[SafeHavenSchema] = None
    channel_used: str = Field(..., description="INTERNET, SMS, PEER_RELAY, OFFLINE_QUEUE")
    blockchain_tx_hash: Optional[str] = None

class BlockchainRecordSchema(BaseModel):
    incident_id: str
    event_type: str
    timestamp: datetime
    location_hash: str
    payload_hash: str
    tx_hash: str
    block_number: int
    status: str = "VERIFIED_ON_CHAIN"

class SyncBatchRequestSchema(BaseModel):
    device_id: str
    queued_incidents: List[IncidentPayloadSchema]

class SyncResponseSchema(BaseModel):
    status: str
    synced_count: int
    server_timestamp: datetime
    processed_incident_ids: List[str]
