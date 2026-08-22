class IncidentPayload {
  final String incidentId;
  final String userId;
  final DateTime timestamp;
  final String eventType; // 'SOS_TRIGGERED' | 'RISK_ESCALATED' | 'SAFE_HAVEN_SELECTED' | 'INCIDENT_RESOLVED'
  final Map<String, dynamic> location; // {lat, lon, source, confidence}
  final Map<String, dynamic> riskAssessment; // {risk, score, reasons}
  final Map<String, dynamic>? safeHaven;
  final String channelUsed; // 'INTERNET' | 'SMS' | 'PEER_RELAY' | 'OFFLINE_QUEUE'
  final String? blockchainTxHash;

  IncidentPayload({
    required this.incidentId,
    required this.userId,
    required this.timestamp,
    required this.eventType,
    required this.location,
    required this.riskAssessment,
    this.safeHaven,
    required this.channelUsed,
    this.blockchainTxHash,
  });

  Map<String, dynamic> toJson() => {
        'incident_id': incidentId,
        'user_id': userId,
        'timestamp': timestamp.toIso8601String(),
        'event_type': eventType,
        'location': location,
        'risk_assessment': riskAssessment,
        'safe_haven': safeHaven,
        'channel_used': channelUsed,
        'blockchain_tx_hash': blockchainTxHash,
      };

  factory IncidentPayload.fromJson(Map<String, dynamic> json) {
    return IncidentPayload(
      incidentId: json['incident_id'],
      userId: json['user_id'],
      timestamp: DateTime.parse(json['timestamp']),
      eventType: json['event_type'],
      location: Map<String, dynamic>.from(json['location']),
      riskAssessment: Map<String, dynamic>.from(json['risk_assessment']),
      safeHaven: json['safe_haven'] != null ? Map<String, dynamic>.from(json['safe_haven']) : null,
      channelUsed: json['channel_used'],
      blockchainTxHash: json['blockchain_tx_hash'],
    );
  }
}
