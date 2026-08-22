import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/delivery_result.dart';
import '../models/safety_event.dart';
import 'safety_event_transport.dart';

/// Real HTTP transport communicating with an external or local safety backend server.
class RealHttpSafetyEventTransport implements SafetyEventTransport {
  /// Base URL of the backend server (e.g. "http://192.168.1.100:8080" for LAN,
  /// "http://10.0.2.2:8080" for Android emulator, or "https://api.touristsafety.org").
  String baseUrl;

  /// API endpoint path for safety event ingestion.
  final String endpointPath;

  /// Underlying HTTP client instance.
  final http.Client _client;

  /// Flag indicating if the HTTP client was created internally and should be closed on dispose.
  final bool _ownsClient;

  /// Configurable request and network timeout.
  final Duration timeout;

  /// Default base URL. For Android emulators use 10.0.2.2, for physical devices use the host LAN IP.
  static const String defaultBaseUrl = 'http://10.0.2.2:8080';

  RealHttpSafetyEventTransport({
    String? baseUrl,
    this.endpointPath = '/api/safety-events',
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Full URI constructed from [baseUrl] and [endpointPath].
  Uri get targetUri {
    final sanitizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final sanitizedPath = endpointPath.startsWith('/')
        ? endpointPath
        : '/$endpointPath';
    return Uri.parse('$sanitizedBase$sanitizedPath');
  }

  @override
  Future<DeliveryResult> transmit(SafetyEvent event) async {
    final uri = targetUri;
    _log('[COMM] HTTP ATTEMPT event=${event.eventId}');

    try {
      final jsonPayload = jsonEncode(event.toJson());

      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonPayload,
          )
          .timeout(timeout);

      final statusCode = response.statusCode;

      if (statusCode >= 200 && statusCode < 300) {
        _log('[COMM] HTTP SUCCESS event=${event.eventId} status=$statusCode');

        String? ackMessage;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            ackMessage = decoded['message'].toString();
          }
        } catch (_) {
          // Ignore JSON decode errors for non-JSON or plain responses
        }

        _log('[COMM] HTTP ACK event=${event.eventId}');

        return DeliveryResult.success(
          channelName: 'HTTP',
          resultingStatus: EventDeliveryStatus.sent,
          reason: ackMessage ?? 'HTTP $statusCode Accepted by server',
        );
      } else {
        _log('[COMM] HTTP FAILURE event=${event.eventId} status=$statusCode');
        return DeliveryResult.failure(
          channelName: 'HTTP',
          reason: 'HTTP $statusCode: ${response.body}',
        );
      }
    } on TimeoutException {
      _log('[COMM] HTTP FAILURE event=${event.eventId} reason=timeout');
      return DeliveryResult.failure(
        channelName: 'HTTP',
        reason: 'HTTP request timed out after ${timeout.inSeconds}s (timeout)',
      );
    } on SocketException catch (e) {
      _log('[COMM] HTTP FAILURE event=${event.eventId} reason=connection refused (${e.message})');
      return DeliveryResult.failure(
        channelName: 'HTTP',
        reason: 'Network connection failed: ${e.message}',
      );
    } on http.ClientException catch (e) {
      _log('[COMM] HTTP FAILURE event=${event.eventId} reason=${e.message}');
      return DeliveryResult.failure(
        channelName: 'HTTP',
        reason: 'HTTP client error: ${e.message}',
      );
    } catch (e) {
      _log('[COMM] HTTP FAILURE event=${event.eventId} reason=$e');
      return DeliveryResult.failure(
        channelName: 'HTTP',
        reason: 'Network error: $e',
      );
    }
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
