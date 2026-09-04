import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/sensor_diagnostics_model.dart';
import '../models/twin_sensor_signals.dart';

/// Normalized multi-axis sensor sample combining accelerometer & gyroscope.
class SensorSample {
  final DateTime timestamp;

  // Raw acceleration in m/s^2 (includes gravity)
  final double ax;
  final double ay;
  final double az;

  // Angular rate of rotation in rad/s
  final double gx;
  final double gy;
  final double gz;

  // Euclidean magnitudes (orientation invariant)
  final double accelMagnitude;
  final double gyroMagnitude;

  // Gravity-separated linear user acceleration in m/s^2
  final double userAx;
  final double userAy;
  final double userAz;
  final double userAccelMagnitude;

  final String source;

  const SensorSample({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.accelMagnitude,
    required this.gyroMagnitude,
    required this.userAx,
    required this.userAy,
    required this.userAz,
    required this.userAccelMagnitude,
    this.source = 'PHONE_INTERNAL_SENSORS',
  });

  /// Factory creating sample with real-time gravity separation.
  factory SensorSample.fromRaw({
    required DateTime timestamp,
    required double ax,
    required double ay,
    required double az,
    required double gx,
    required double gy,
    required double gz,
    required double gravityX,
    required double gravityY,
    required double gravityZ,
    String source = 'PHONE_INTERNAL_SENSORS',
  }) {
    final aMag = math.sqrt(ax * ax + ay * ay + az * az);
    final gMag = math.sqrt(gx * gx + gy * gy + gz * gz);

    final uAx = ax - gravityX;
    final uAy = ay - gravityY;
    final uAz = az - gravityZ;
    final uAMag = math.sqrt(uAx * uAx + uAy * uAy + uAz * uAz);

    return SensorSample(
      timestamp: timestamp,
      ax: ax,
      ay: ay,
      az: az,
      gx: gx,
      gy: gy,
      gz: gz,
      accelMagnitude: aMag,
      gyroMagnitude: gMag,
      userAx: uAx,
      userAy: uAy,
      userAz: uAz,
      userAccelMagnitude: uAMag,
      source: source,
    );
  }
}

/// Unified phone hardware motion pipeline.
///
/// Ingests raw accelerometer and gyroscope streams from sensors_plus,
/// applies real-time orientation-invariant gravity separation,
/// calculates continuous sample frequencies, and feeds normalized samples
/// to step detection and activity classification.
class PhoneMotionPipeline {
  final StreamController<SensorSample> _sampleController =
      StreamController<SensorSample>.broadcast();

  final ValueNotifier<SensorDiagnosticsData> diagnosticsNotifier =
      ValueNotifier(const SensorDiagnosticsData());

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // Custom streams for testing & fixture simulation
  final Stream<AccelerometerEvent>? customAccelStream;
  final Stream<GyroscopeEvent>? customGyroStream;

  // Gravity Filter State (Exponential Moving Average)
  // alpha = 0.80 retains slow-changing gravity vector while passing dynamic motion
  final double gravityAlpha;
  double _gravityX = 0.0;
  double _gravityY = 9.81;
  double _gravityZ = 0.0;
  bool _gravityInitialized = false;

  // Most recent readings for sample fusion
  double _latestAx = 0.0;
  double _latestAy = 9.81;
  double _latestAz = 0.0;

  double _latestGx = 0.0;
  double _latestGy = 0.0;
  double _latestGz = 0.0;

  // Sampling Rate Estimators (moving timestamp buffers)
  final List<DateTime> _accelTimestamps = [];
  final List<DateTime> _gyroTimestamps = [];
  int _accelCount = 0;
  int _gyroCount = 0;

  bool _isActive = false;

  PhoneMotionPipeline({
    this.gravityAlpha = 0.80,
    this.customAccelStream,
    this.customGyroStream,
  });

  Stream<SensorSample> get sampleStream => _sampleController.stream;
  bool get isActive => _isActive;
  SensorDiagnosticsData get currentDiagnostics => diagnosticsNotifier.value;

  /// Starts listening to phone internal accelerometer & gyroscope.
  void start() {
    if (_isActive) return;
    _isActive = true;

    // 1. Subscribe to Accelerometer
    final accelStream = customAccelStream ??
        accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval);

    try {
      _accelSub = accelStream.listen(
        _handleAccelerometerEvent,
        onError: (e) {
          diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
            accelReceiving: false,
          );
        },
      );
    } catch (_) {
      diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
        accelReceiving: false,
      );
    }

    // 2. Subscribe to Gyroscope
    final gyroStream = customGyroStream ??
        gyroscopeEventStream(samplingPeriod: SensorInterval.normalInterval);

    try {
      _gyroSub = gyroStream.listen(
        _handleGyroscopeEvent,
        onError: (e) {
          diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
            gyroReceiving: false,
          );
        },
      );
    } catch (_) {
      diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
        gyroReceiving: false,
      );
    }

    diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
      sensorStreamActive: true,
      filteringActive: true,
    );
  }

  void _handleAccelerometerEvent(AccelerometerEvent event) {
    final now = DateTime.now();
    _accelCount++;
    _latestAx = event.x;
    _latestAy = event.y;
    _latestAz = event.z;

    // Gravity Separation (Low-pass EMA)
    if (!_gravityInitialized) {
      _gravityX = event.x;
      _gravityY = event.y;
      _gravityZ = event.z;
      _gravityInitialized = true;
    } else {
      _gravityX = gravityAlpha * _gravityX + (1.0 - gravityAlpha) * event.x;
      _gravityY = gravityAlpha * _gravityY + (1.0 - gravityAlpha) * event.y;
      _gravityZ = gravityAlpha * _gravityZ + (1.0 - gravityAlpha) * event.z;
    }

    // Estimate sampling frequency (last 30 samples)
    _accelTimestamps.add(now);
    if (_accelTimestamps.length > 30) {
      _accelTimestamps.removeAt(0);
    }
    double estHz = 0.0;
    if (_accelTimestamps.length >= 2) {
      final elapsedSec = _accelTimestamps.last
              .difference(_accelTimestamps.first)
              .inMicroseconds /
          1000000.0;
      if (elapsedSec > 0) {
        estHz = (_accelTimestamps.length - 1) / elapsedSec;
      }
    }

    // Fuse with latest Gyroscope state
    final sample = SensorSample.fromRaw(
      timestamp: now,
      ax: _latestAx,
      ay: _latestAy,
      az: _latestAz,
      gx: _latestGx,
      gy: _latestGy,
      gz: _latestGz,
      gravityX: _gravityX,
      gravityY: _gravityY,
      gravityZ: _gravityZ,
    );

    if (!_sampleController.isClosed) {
      _sampleController.add(sample);
    }

    // Update Diagnostics
    diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
      accelReceiving: true,
      accelSampleCount: _accelCount,
      accelLastTimestamp: now,
      accelEstimatedHz: double.parse(estHz.toStringAsFixed(1)),
      accelX: double.parse(event.x.toStringAsFixed(2)),
      accelY: double.parse(event.y.toStringAsFixed(2)),
      accelZ: double.parse(event.z.toStringAsFixed(2)),
      accelMagnitude: double.parse(sample.accelMagnitude.toStringAsFixed(2)),
      userAccelMagnitude:
          double.parse(sample.userAccelMagnitude.toStringAsFixed(2)),
      sensorStreamActive: true,
      filteringActive: true,
    );
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    final now = DateTime.now();
    _gyroCount++;
    _latestGx = event.x;
    _latestGy = event.y;
    _latestGz = event.z;

    // Estimate Gyroscope sampling frequency
    _gyroTimestamps.add(now);
    if (_gyroTimestamps.length > 30) {
      _gyroTimestamps.removeAt(0);
    }
    double estHz = 0.0;
    if (_gyroTimestamps.length >= 2) {
      final elapsedSec = _gyroTimestamps.last
              .difference(_gyroTimestamps.first)
              .inMicroseconds /
          1000000.0;
      if (elapsedSec > 0) {
        estHz = (_gyroTimestamps.length - 1) / elapsedSec;
      }
    }

    final gMag =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Update Diagnostics
    diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
      gyroReceiving: true,
      gyroSampleCount: _gyroCount,
      gyroLastTimestamp: now,
      gyroEstimatedHz: double.parse(estHz.toStringAsFixed(1)),
      gyroX: double.parse(event.x.toStringAsFixed(3)),
      gyroY: double.parse(event.y.toStringAsFixed(3)),
      gyroZ: double.parse(event.z.toStringAsFixed(3)),
      gyroMagnitude: double.parse(gMag.toStringAsFixed(3)),
    );
  }

  /// Updates downstream processor diagnostics (step count, activity, confidence).
  void updateProcessorDiagnostics({
    int? detectedSteps,
    TwinActivityType? currentActivity,
    double? confidence,
    DateTime? lastTransitionTime,
    DateTime? lastTwinSignalEmittedAt,
    bool? stepDetectorActive,
    bool? activityClassifierActive,
  }) {
    diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
      detectedSteps: detectedSteps,
      currentActivity: currentActivity,
      confidence: confidence,
      lastTransitionTime: lastTransitionTime,
      lastTwinSignalEmittedAt: lastTwinSignalEmittedAt,
      stepDetectorActive: stepDetectorActive,
      activityClassifierActive: activityClassifierActive,
    );
  }

  /// Stops all listeners and cleans up subscriptions.
  void stop() {
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _isActive = false;

    diagnosticsNotifier.value = diagnosticsNotifier.value.copyWith(
      sensorStreamActive: false,
      filteringActive: false,
      accelReceiving: false,
      gyroReceiving: false,
    );
  }

  void dispose() {
    stop();
    _sampleController.close();
    diagnosticsNotifier.dispose();
  }
}
