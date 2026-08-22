class BlockchainRecord {
  final String incidentId;
  final String eventType;
  final DateTime timestamp;
  final String locationHash;
  final String payloadHash;
  final String txHash;
  final int blockNumber;
  final String status;

  BlockchainRecord({
    required this.incidentId,
    required this.eventType,
    required this.timestamp,
    required this.locationHash,
    required this.payloadHash,
    required this.txHash,
    required this.blockNumber,
    this.status = "VERIFIED_ON_CHAIN",
  });

  Map<String, dynamic> toJson() => {
        'incident_id': incidentId,
        'event_type': eventType,
        'timestamp': timestamp.toIso8601String(),
        'location_hash': locationHash,
        'payload_hash': payloadHash,
        'tx_hash': txHash,
        'block_number': blockNumber,
        'status': status,
      };

  factory BlockchainRecord.fromJson(Map<String, dynamic> json) {
    return BlockchainRecord(
      incidentId: json['incident_id'],
      eventType: json['event_type'],
      timestamp: DateTime.parse(json['timestamp']),
      locationHash: json['location_hash'],
      payloadHash: json['payload_hash'],
      txHash: json['tx_hash'],
      blockNumber: json['block_number'] ?? 0,
      status: json['status'] ?? "VERIFIED_ON_CHAIN",
    );
  }
}
