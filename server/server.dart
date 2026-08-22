// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// In-memory store for safety events received by the backend server.
final Map<String, Map<String, dynamic>> _receivedEvents = {};

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ??
      (args.isNotEmpty ? int.tryParse(args[0]) : null) ??
      8080;

  // Bind to all IPv4 interfaces (0.0.0.0) so physical phones on LAN and emulators can connect
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  // Discover local network IPv4 addresses to assist user connecting their physical Android phone
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  print('================================================================');
  print('🛡️  TOURIST SAFETY SYSTEM — PROTOTYPE HTTP BACKEND SERVER');
  print('================================================================');
  print(' Listening on port $port');
  print(' Localhost:    http://localhost:$port');
  print(' Android Emu:  http://10.0.2.2:$port');
  print(' Physical Phone LAN candidates:');
  for (final interface in interfaces) {
    for (final addr in interface.addresses) {
      if (!addr.isLoopback) {
        print('   • http://${addr.address}:$port (${interface.name})');
      }
    }
  }
  print(' Endpoint:     POST /api/safety-events');
  print(' Health Check: GET  /api/safety-events or GET /health');
  print('================================================================\n');

  await for (HttpRequest request in server) {
    _handleRequest(request);
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  final response = request.response;

  // CORS Headers for browser/dashboard compatibility
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Accept');

  if (request.method == 'OPTIONS') {
    response.statusCode = HttpStatus.ok;
    await response.close();
    return;
  }

  final path = request.uri.path;

  // Health check endpoint
  if (request.method == 'GET' && (path == '/health' || path == '/')) {
    response.headers.contentType = ContentType.json;
    response.statusCode = HttpStatus.ok;
    response.write(jsonEncode({
      'status': 'HEALTHY',
      'service': 'Tourist Safety Backend',
      'timestamp': DateTime.now().toIso8601String(),
      'storedEventsCount': _receivedEvents.length,
    }));
    await response.close();
    return;
  }

  // Query received events (useful for verification/inspection)
  if (request.method == 'GET' && path == '/api/safety-events') {
    response.headers.contentType = ContentType.json;
    response.statusCode = HttpStatus.ok;
    response.write(jsonEncode({
      'success': true,
      'count': _receivedEvents.length,
      'events': _receivedEvents.values.toList(),
    }));
    await response.close();
    return;
  }

  // Safety event ingestion endpoint
  if (request.method == 'POST' && path == '/api/safety-events') {
    try {
      final bodyString = await utf8.decodeStream(request);
      if (bodyString.trim().isEmpty) {
        _sendJsonError(response, HttpStatus.badRequest, 'Empty request body');
        return;
      }

      final dynamic decoded = jsonDecode(bodyString);
      if (decoded is! Map<String, dynamic>) {
        _sendJsonError(response, HttpStatus.badRequest, 'Payload must be a JSON object');
        return;
      }

      final eventId = decoded['eventId'] as String?;
      if (eventId == null || eventId.trim().isEmpty) {
        _sendJsonError(response, HttpStatus.badRequest, 'Missing required field: eventId');
        return;
      }

      final eventType = decoded['eventType'] ?? 'UNKNOWN';
      final lat = decoded['latitude'];
      final lon = decoded['longitude'];
      final source = decoded['positionSource'] ?? 'NONE';
      final clientStatus = decoded['eventStatus'] ?? 'UNKNOWN';

      // Idempotency check: if event was already recorded, acknowledge without duplication
      final isDuplicate = _receivedEvents.containsKey(eventId);
      if (isDuplicate) {
        print('[SERVER] 🔁 DUPLICATE eventId=$eventId (Idempotent ACK returned)');
        response.headers.contentType = ContentType.json;
        response.statusCode = HttpStatus.ok;
        response.write(jsonEncode({
          'success': true,
          'eventId': eventId,
          'message': 'Safety event already received (idempotent ack)',
          'duplicate': true,
          'timestamp': DateTime.now().toIso8601String(),
        }));
        await response.close();
        return;
      }

      // Record new event
      _receivedEvents[eventId] = decoded;

      print('[SERVER] 📥 RECEIVED eventId=$eventId type=$eventType lat=$lat lon=$lon source=$source clientStatus=$clientStatus (total stored: ${_receivedEvents.length})');

      response.headers.contentType = ContentType.json;
      response.statusCode = HttpStatus.created; // HTTP 201 Created
      response.write(jsonEncode({
        'success': true,
        'eventId': eventId,
        'message': 'Safety event received and acknowledged',
        'timestamp': DateTime.now().toIso8601String(),
      }));
      await response.close();
      return;
    } catch (e) {
      print('[SERVER] ❌ ERROR processing request: $e');
      _sendJsonError(response, HttpStatus.internalServerError, 'Internal server error: $e');
      return;
    }
  }

  // Not found for other routes
  _sendJsonError(response, HttpStatus.notFound, 'Route not found: ${request.method} $path');
}

void _sendJsonError(HttpResponse response, int statusCode, String message) {
  response.headers.contentType = ContentType.json;
  response.statusCode = statusCode;
  response.write(jsonEncode({
    'success': false,
    'error': message,
    'statusCode': statusCode,
  }));
  response.close();
}
