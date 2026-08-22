# schemas.py
# Pydantic v2 data contracts — the single source of truth shared across all team members P1-P6.
# Every API input/output shape is defined here. DO NOT change field names without team alignment.

from pydantic import BaseModel, Field
from typing import Optional, List, Any
from datetime import datetime


# ─── P1 PRODUCES THIS ────────────────────────────────────────────────────────
class LocationEstimate(BaseModel):
    """Location data produced by P1 (GPS/PDR sensor fusion module)."""
    lat: float
    lon: float
    source: str = Field(..., pattern="^(GPS|PDR|WIFI|COMBINED)$")
    confidence: float = Field(..., ge=0.0, le=1.0)  # always a float, never a string
    timestamp: Optional[str] = None
    session_id: Optional[str] = None


class LocationEstimateResponse(LocationEstimate):
    id: int
    nearest_hotspot: Optional[dict] = None

    class Config:
        from_attributes = True


# ─── P2 PRODUCES / READS THIS ────────────────────────────────────────────────
class HotspotResponse(BaseModel):
    """Hotspot record — P2 reads these for the crime layer on the map."""
    id: str
    center_lat: float
    center_lon: float
    radius_m: int
    risk_level: str
    reported_incidents: int    # NOTE: never call this "crime_rate"
    recent_incidents: int
    hotspot_score: float

    class Config:
        from_attributes = True


class HotspotListResponse(BaseModel):
    hotspots: List[HotspotResponse]
    total: int


# ─── SAFE LOCATIONS ───────────────────────────────────────────────────────────
class SafeLocationCreate(BaseModel):
    name: str
    latitude: float
    longitude: float
    type: str
    availability: str = "unknown"
    phone: Optional[str] = None


class SafeLocationResponse(SafeLocationCreate):
    id: int

    class Config:
        from_attributes = True


# ─── P3 PRODUCES THIS ─────────────────────────────────────────────────────────
class RiskAssessmentCreate(BaseModel):
    """Risk assessment produced by P3 (risk engine)."""
    session_id: str
    risk_level: str = Field(..., pattern="^(LOW|MEDIUM|HIGH|CRITICAL)$")
    score: int = Field(..., ge=0, le=100)
    reasons: List[str]
    hotspot_id: Optional[str] = None


class RiskAssessmentResponse(RiskAssessmentCreate):
    id: int
    timestamp: datetime

    class Config:
        from_attributes = True


# ─── P4 PRODUCES THIS ─────────────────────────────────────────────────────────
class CommunicationStatusCreate(BaseModel):
    """Communication channel status from P4."""
    incident_id: str
    internet: bool
    sms: bool
    relay: bool
    selected_channel: str


class IncidentEventCreate(BaseModel):
    """A single event in an incident timeline, sent by P4."""
    incident_id: str
    event_type: str
    description: str
    data: Optional[dict] = None


class IncidentCreate(BaseModel):
    """Incident creation payload — triggered when tourist presses 'I Feel Unsafe'."""
    session_id: str
    risk_level: str
    lat: float
    lon: float
    location_source: str
    location_confidence: float
    blockchain_hash: Optional[str] = None


class IncidentResponse(BaseModel):
    """Full incident with timeline events — used by P6 for the incident dashboard."""
    id: str
    session_id: str
    started_at: Optional[str]
    resolved_at: Optional[str]
    status: str
    risk_level: str
    lat: float
    lon: float
    location_source: str
    location_confidence: float
    blockchain_hash: Optional[str]
    events: List[dict] = []

    class Config:
        from_attributes = True


# ─── OFFLINE SYNC (P4 sends queued events when connectivity returns) ──────────
class OfflineSyncPayload(BaseModel):
    """
    Batch of events that P4 queued while offline.
    Each event in queued_events has a 'type' field:
      "location", "risk", "incident_event", "communication"
    The /sync endpoint MUST process each event individually — never reject the entire batch.
    """
    session_id: str
    queued_events: List[dict]   # list of typed event dicts
    synced_at: str


# ─── UNIFIED SAFETY STATE (P6 dashboard reads this) ──────────────────────────
class UnifiedSafetyState(BaseModel):
    """
    THE locked unified object shape. Field names are frozen — P1, P3, P4, P6 all depend on them.
    Returned by GET /unified-state?session_id=...
    """
    lat: float
    lon: float
    confidence: float
    source: str
    risk: str
    score: int
    hotspot_id: Optional[str]
    reported_incidents: Optional[int]
    internet: bool
    sms: bool
    relay: bool
    selected_channel: str
    nearest_safe_location: Optional[dict]
