from typing import List, Dict, Optional
import datetime
from models import IncidentPayloadSchema, BlockchainRecordSchema

class MockDatabase:
    def __init__(self):
        self.incidents: Dict[str, IncidentPayloadSchema] = {}
        self.blockchain_ledger: List[BlockchainRecordSchema] = []

    def save_incident(self, incident: IncidentPayloadSchema):
        self.incidents[incident.incident_id] = incident
        return incident

    def save_blockchain_record(self, record: BlockchainRecordSchema):
        self.blockchain_ledger.append(record)
        return record

    def get_all_incidents(self) -> List[IncidentPayloadSchema]:
        return list(self.incidents.values())

    def get_all_blockchain_records(self) -> List[BlockchainRecordSchema]:
        return self.blockchain_ledger

db = MockDatabase()
