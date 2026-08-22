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
        debugPrint('RAW EVENT = $event');

        if (event is! Map) {
          debugPrint('STEP SENSOR: Ignoring non-map event');
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

          debugPrint('STEP SENSOR STATUS -> $sensorStatus');

          onStatusUpdate(sensorStatus);

          return;
        }

        // ======================================================
        // NATIVE STEP COUNTER
        // ======================================================

        if (type == 'counter') {
          final rawValue = event['steps'];

          if (rawValue is! num) {
            debugPrint('STEP COUNTER: invalid value=$rawValue');
            return;
          }

          final rawSteps = rawValue.toInt();

          debugPrint('STEP COUNTER EVENT -> rawSteps=$rawSteps');

          // ----------------------------------------------------
          // FIRST COUNTER READING
          // ----------------------------------------------------

          if (_initialCounter == null) {
            _initialCounter = rawSteps;
            _lastCounter = rawSteps;

            counterSteps = 0;

            debugPrint('STEP COUNTER BASELINE -> $rawSteps');

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
            debugPrint('STEP COUNTER RESET DETECTED');

            _initialCounter = rawSteps;
            _lastCounter = rawSteps;

            counterSteps = 0;

            return;
          }

          _lastCounter = rawSteps;

          counterSteps = calculatedSteps;

          debugPrint('STEP COUNTER SESSION VALUE -> $counterSteps');

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
          final rawDetectorSteps = event['steps'];

          debugPrint('STEP DETECTOR EVENT -> steps=$rawDetectorSteps');

          // ----------------------------------------------------
          // EVERY DETECTOR EVENT REPRESENTS ONE NEW STEP
          // ----------------------------------------------------

          detectorSteps++;

          sessionSteps = detectorSteps;

          debugPrint('STEP SESSION TOTAL -> $sessionSteps');

          // ----------------------------------------------------
          // THIS IS NOW THE AUTHORITATIVE LIVE CALLBACK
          // ----------------------------------------------------

          onStepUpdate(sessionSteps);

          return;
        }

        // ======================================================
        // UNKNOWN EVENT
        // ======================================================

        debugPrint('STEP SENSOR: Unknown event type=$type');
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
