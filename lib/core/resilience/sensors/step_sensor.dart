import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class StepSensor {
  static const EventChannel _channel = EventChannel('sih/native_step_events');

  StreamSubscription? _subscription;

  // ============================================================
  // SESSION STATE
  // ============================================================

  int sessionSteps = 0;

  bool isAvailable = false;

  String status = 'INITIALIZING';

  // ============================================================
  // NATIVE COUNTER STATE
  // ============================================================

  int? _initialCounter;

  int? _lastCounter;
  int? get lastCounter => _lastCounter;

  int counterSteps = 0;

  // ============================================================
  // DETECTOR STATE
  // ============================================================

  int detectorSteps = 0;

  // ============================================================
  // START
  // ============================================================

  void start({
    required void Function(int steps) onStepUpdate,
    required void Function(String status) onStatusUpdate,
    required void Function(String error) onError,
  }) {
    _subscription?.cancel();

    // Reset session state whenever sensor starts.
    _initialCounter = null;
    _lastCounter = null;

    sessionSteps = 0;
    counterSteps = 0;
    detectorSteps = 0;

    status = 'INITIALIZING';
    isAvailable = false;

    onStatusUpdate(status);

    _subscription = _channel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is! Map) {
          return;
        }

        final type = event['type'];

        // ======================================================
        // SENSOR STATUS
        // ======================================================

        if (type == 'status') {
          final sensorStatus = event['status']?.toString() ?? 'UNKNOWN';

          status = sensorStatus;
          isAvailable = sensorStatus == 'AVAILABLE';

          onStatusUpdate(sensorStatus);

          return;
        }

        // ======================================================
        // NATIVE STEP COUNTER
        // ======================================================

        if (type == 'counter') {
          final rawValue = event['steps'];

          if (rawValue is! num) {
            return;
          }

          final rawSteps = rawValue.toInt();

          // ----------------------------------------------------
          // FIRST COUNTER READING
          // ----------------------------------------------------

          if (_initialCounter == null) {
            _initialCounter = rawSteps;
            _lastCounter = rawSteps;

            counterSteps = 0;

            // IMPORTANT:
            //
            // Do NOT reset sessionSteps here.
            //
            // The detector may already have detected steps.
            //
            return;
          }

          // ----------------------------------------------------
          // CALCULATE COUNTER SESSION VALUE
          // ----------------------------------------------------

          final calculatedSteps = rawSteps - _initialCounter!;

          // ----------------------------------------------------
          // COUNTER RESET PROTECTION
          // ----------------------------------------------------

          if (calculatedSteps < 0) {
            _initialCounter = rawSteps;
            _lastCounter = rawSteps;

            counterSteps = 0;

            return;
          }

          _lastCounter = rawSteps;

          counterSteps = calculatedSteps;

          // ----------------------------------------------------
          // IMPORTANT
          // ----------------------------------------------------
          //
          // We DO NOT update sessionSteps from the counter.
          //
          // Android TYPE_STEP_COUNTER can be delayed.
          //
          // The detector is providing immediate movement events.
          //
          return;
        }

        // ======================================================
        // STEP DETECTOR
        // ======================================================

        if (type == 'detector') {
          // ----------------------------------------------------
          // EVERY DETECTOR EVENT REPRESENTS ONE NEW STEP
          // ----------------------------------------------------

          detectorSteps++;

          sessionSteps = detectorSteps;

          // ----------------------------------------------------
          // THIS IS NOW THE AUTHORITATIVE LIVE CALLBACK
          // ----------------------------------------------------

          onStepUpdate(sessionSteps);

          return;
        }
      },

      onError: (dynamic error) {
        status = 'UNAVAILABLE';
        isAvailable = false;

        debugPrint('STEP SENSOR ERROR -> $error');

        onStatusUpdate(status);
        onError(error.toString());
      },

      cancelOnError: false,
    );
  }

  // ============================================================
  // RESET
  // ============================================================

  void reset() {
    _initialCounter = null;
    _lastCounter = null;

    sessionSteps = 0;
    counterSteps = 0;
    detectorSteps = 0;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _subscription?.cancel();

    _subscription = null;

    _initialCounter = null;
    _lastCounter = null;

    sessionSteps = 0;
    counterSteps = 0;
    detectorSteps = 0;

    isAvailable = false;
    status = 'STOPPED';
  }
}
