from fastapi import APIRouter, HTTPException, status
from datetime import datetime
from typing import List
from models import SyncBatchRequestSchema, SyncResponseSchema, IncidentPayloadSchema, BlockchainRecordSchema
from database import db

router = APIRouter(prefix="/api/v1", tags=["Resilience & Sync"])

@router.post("/sync", response_model=SyncResponseSchema, status_code=status.HTTP_200_OK)
async def sync_offline_incidents(payload: SyncBatchRequestSchema):
    processed_ids = []
    for incident in payload.queued_incidents:
        db.save_incident(incident)
        processed_ids.append(incident.incident_id)
        
        # If incident has a blockchain transaction hash, record in audit ledger
        if incident.blockchain_tx_hash:
            bc_record = BlockchainRecordSchema(
                incident_id=incident.incident_id,
                event_type=incident.event_type,
                timestamp=incident.timestamp,
                location_hash=f"0xloc_{hash((incident.location.lat, incident.location.lon))}",
                payload_hash=f"0xpay_{hash(incident.incident_id)}",
                tx_hash=incident.blockchain_tx_hash,
                block_number=142857,
                status="VERIFIED_ON_CHAIN"
            )
            db.save_blockchain_record(bc_record)

    return SyncResponseSchema(
        status="SUCCESS",
        synced_count=len(processed_ids),
        server_timestamp=datetime.utcnow(),
        processed_incident_ids=processed_ids
    )

@router.post("/incident", response_model=IncidentPayloadSchema, status_code=status.HTTP_201_CREATED)
async def trigger_realtime_incident(incident: IncidentPayloadSchema):
    db.save_incident(incident)
    return incident

@router.get("/incidents", response_model=List[IncidentPayloadSchema])
async def get_all_incidents():
    return db.get_all_incidents()

@router.get("/blockchain/records", response_model=List[BlockchainRecordSchema])
async def get_blockchain_records():
    return db.get_all_blockchain_records()
