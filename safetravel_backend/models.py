# models.py
# SQLAlchemy ORM table definitions for all SafeTravel backend tables
from sqlalchemy import (
    Column, Integer, Float, String, DateTime, Boolean, Text, ForeignKey
)
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime, timezone


class LocationEstimate(Base):
    """Stores tourist location data from P1 (GPS or PDR)."""
    __tablename__ = "location_estimates"

    id = Column(Integer, primary_key=True, autoincrement=True)
    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)
    source = Column(String, nullable=False)        # "GPS", "PDR", "WIFI", "COMBINED"
    confidence = Column(Float, nullable=False)     # 0.0 to 1.0
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    session_id = Column(String, nullable=True)


class CrimeIncident(Base):
    """Raw crime records ingested from datasets via the crime data pipeline."""
    __tablename__ = "crime_incidents"

    id = Column(Integer, primary_key=True, autoincrement=True)
    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)
    crime_type = Column(String, nullable=False)    # e.g. "theft", "assault"
    date = Column(DateTime, nullable=True)
    severity = Column(Integer, nullable=False)     # 1 (low) to 5 (high)
    source = Column(String, nullable=True)         # dataset origin


class Hotspot(Base):
    """
    Geographic crime hotspot cells — produced by the crime data pipeline.
    Each hotspot is a 300m-radius cell with a computed risk score.
    """
    __tablename__ = "hotspots"

    id = Column(String, primary_key=True)          # e.g. "H12"
    center_lat = Column(Float, nullable=False)
    center_lon = Column(Float, nullable=False)
    radius_m = Column(Integer, default=300)
    risk_level = Column(String, nullable=False)    # "HIGH", "MEDIUM", "LOW"
    reported_incidents = Column(Integer, default=0)
    recent_incidents = Column(Integer, default=0)  # last 30 days
    hotspot_score = Column(Float, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class SafeLocation(Base):
    """Pre-seeded safe locations: hospitals, police stations, hotels, etc."""
    __tablename__ = "safe_locations"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    type = Column(String, nullable=False)          # "hospital", "police", "hotel", "railway", "tourist_centre"
    availability = Column(String, default="unknown")  # "24x7", "9am-6pm", "unknown"
    phone = Column(String, nullable=True)


class RiskAssessment(Base):
    """Risk assessment records produced by P3 for each session."""
    __tablename__ = "risk_assessments"

    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(String, nullable=False)
    risk_level = Column(String, nullable=False)    # "LOW", "MEDIUM", "HIGH", "CRITICAL"
    score = Column(Integer, nullable=False)        # 0–100
    reasons = Column(Text, nullable=True)          # JSON string list
    hotspot_id = Column(String, ForeignKey("hotspots.id"), nullable=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class Incident(Base):
    """
    Incident lifecycle record — created when tourist triggers 'I Feel Unsafe'.
    Holds the full lifecycle from ACTIVE to RESOLVED, including blockchain hash from P4.
    """
    __tablename__ = "incidents"

    id = Column(String, primary_key=True)           # "INC-{timestamp_ms}"
    session_id = Column(String, nullable=False)
    started_at = Column(DateTime, nullable=False)
    resolved_at = Column(DateTime, nullable=True)
    status = Column(String, default="ACTIVE")        # "ACTIVE", "RESOLVED"
    risk_level = Column(String, nullable=False)
    lat = Column(Float, nullable=False)
    lon = Column(Float, nullable=False)
    location_source = Column(String, nullable=False)
    location_confidence = Column(Float, nullable=False)
    blockchain_hash = Column(String, nullable=True)  # from P4

    events = relationship(
        "IncidentEvent",
        back_populates="incident",
        order_by="IncidentEvent.timestamp",
        cascade="all, delete-orphan"
    )
    communication_events = relationship(
        "CommunicationEvent",
        back_populates="incident",
        cascade="all, delete-orphan"
    )


class IncidentEvent(Base):
    """
    Individual timeline events within an incident.
    Event types: GPS_LOST, PDR_ACTIVATED, SOS_TRIGGERED, SAFE_HAVEN_SELECTED,
                 NETWORK_RESTORED, INCIDENT_RESOLVED, RELAY_USED, BLOCKCHAIN_RECORDED
    """
    __tablename__ = "incident_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    incident_id = Column(String, ForeignKey("incidents.id"), nullable=False)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    event_type = Column(String, nullable=False)
    description = Column(String, nullable=False)
    data = Column(Text, nullable=True)             # JSON blob of extra info

    incident = relationship("Incident", back_populates="events")


class CommunicationEvent(Base):
    """Communication channel status log from P4."""
    __tablename__ = "communication_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    incident_id = Column(String, ForeignKey("incidents.id"), nullable=False)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    internet = Column(Boolean, default=True)
    sms = Column(Boolean, default=True)
    relay = Column(Boolean, default=False)
    selected_channel = Column(String, nullable=False)  # "INTERNET", "SMS", "RELAY", "OFFLINE_QUEUE"

    incident = relationship("Incident", back_populates="communication_events")
