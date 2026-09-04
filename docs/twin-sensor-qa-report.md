# Continuum Health — TWIN Real Internal Sensor Pipeline QA & Engineering Report

## Executive Summary

The TWIN (Personal Context and Behavior Twin) sensor processing architecture on mobile has been thoroughly upgraded to ingest, process, and classify real phone hardware sensor data from the internal Accelerometer and Gyroscope. 

Previously, steps stayed at 0 and activity stayed UNKNOWN because:
1. PedometerService prioritized Android's native step counter sensor (Sensor.TYPE_STEP_COUNTER), which hung silently without throwing an error when runtime ACTIVITY_RECOGNITION was missing, preventing the fallback engine from ever starting.
2. The phone's hardware Gyroscope stream was completely unused.
3. Activity recognition relied on userAccelerometerEventStream (Sensor.TYPE_LINEAR_ACCELERATION), an unreliable software-fused synthetic sensor on MediaTek and low-end OEM chipsets.
4. Transient and duplicate TwinSensorCoordinator instances were being created in different Flutter screens rather than utilizing a single shared app-level state provider.

These root causes have been resolved with a dedicated PhoneMotionPipeline, robust raw-hardware low-pass gravity separation, an orientation-invariant adaptive step counter with angular velocity false-positive suppression, windowed activity recognition with a 2-stage hysteresis state machine, a shared Riverpod provider (	winSensorCoordinatorProvider), and a developer-accessible live sensor diagnostics sheet.

---

## 1. Root Cause Diagnosis & Resolution

| Defect / Bottleneck | Root Cause Analysis | Resolution & Architecture Fix |
| :--- | :--- | :--- |
| **Steps stuck at 0** | pedometer plugin calls Android's Sensor.TYPE_STEP_COUNTER. On OEM devices where runtime ACTIVITY_RECOGNITION is ungranted or device is stationary, the stream never emits and never triggers onError, permanently starving the pipeline. | PedometerService now directly binds to PhoneMotionPipeline using the real phone hardware accelerometer and gyroscope as its primary streaming source, emitting PHONE_RAW_SENSOR_STEP_COUNT. |
| **Activity stuck at UNKNOWN** | userAccelerometerEventStream depends on OEM sensor fusion algorithms that frequently return (0, 0, 0) or drop frames under battery optimization. | Direct hardware sensor ingestion via ccelerometerEventStream with an Exponential Moving Average (EMA) low-pass gravity separation filter (\$\alpha = 0.82\$): \$\mathbf{a}_{\text{user}} = \mathbf{a}_{\text{raw}} - \mathbf{g}\$. |
| **Gyroscope Unused** | Gyroscope stream (gyroscopeEventStream) was neither subscribed to nor fused into step detection or activity classification. | PhoneMotionPipeline subscribes to gyroscopeEventStream, computes \$\omega_{\text{mag}} = \sqrt{\omega_x^2 + \omega_y^2 + \omega_z^2}\$, and feeds fused SensorSample objects to step counting and activity recognition. |
| **False Step Counting on Phone Rotation** | Tilting or rotating the phone in hand could generate apparent acceleration spikes that cross naive vertical thresholds. | AdaptivePeakValleyStepCounter now cross-checks angular velocity. If \$\omega_{\text{mag}} > 2.5\ \text{rad/s}\$ and user dynamic acceleration swing is modest (\$<\ 2.8\ m/s^2\$), candidate steps are rejected as pure rotational movement. |
| **Ephemeral Coordinators** | TwinActivityCard and TwinCenterScreen each instantiated their own ephemeral TwinSensorCoordinator(), causing competing subscriptions and state drops on navigation. | Implemented 	winSensorCoordinatorProvider(patientId) via Riverpod in lib/data/sensors/twin_sensor_provider.dart, ensuring a persistent singleton coordinator per patient across the entire widget tree. |

---

## 2. End-to-End Pipeline Architecture

- **Phone Hardware Sensors**: Raw Accelerometer (\/s^2\$) and Gyroscope (\/s\$) streamed continuously.
- **PhoneMotionPipeline**: Direct ingestion, Exponential Moving Average (EMA) gravity separation, rolling 1.0s sample rate frequency estimation, orientation-invariant vector magnitudes (\$\|\mathbf{a}_{\text{raw}}\|\$, \$\|\mathbf{a}_{\text{user}}\|\$, \$\|\boldsymbol{\omega}\|\$).
- **AdaptivePeakValleyStepCounter**: Real-time peak/valley extraction, adaptive magnitude threshold (\.2\ m/s^2\$ minimum swing), refractory timing (\\text{--}1800\ \text{ms}\$), gyroscope angular velocity suppression (\$>\ 2.5\ \text{rad/s}\$), cadence calculation.
- **ActivityRecognitionService**: 50-sample sliding window (\.5\ \text{s}\$ at \\ \text{Hz}\$) extracting \$\sigma_a\$, dynamic swing, RMS acceleration, mean gyroscope rate, and step cadence. 2-consecutive-window hysteresis state machine with 4-second walking pause debounce.
- **SensorDataReconciler**: Authoritative precedence (BLE HR \> Phone HR, Native Step \> Raw Step), duplicate deduplication, daily midnight rollover.
- **TwinSensorCoordinator**: Stream subscription management, offline SQLite/memory queue, background synchronization, reactive Riverpod state.
- **UI & Telemetry**: TwinActivityCard, TwinCenterScreen, and SensorDiagnosticsSheet.

---

## 3. Test Verification Matrix

### 3.1 Flutter Sensor & Motion Test Suite
Ran lutter test test/sensors/:
- **44/44 tests passed (100%)**
- daptive_step_counter_test.dart (12 tests) — PASS
- ctivity_classification_test.dart (5 tests) — PASS
- phone_motion_pipeline_test.dart (3 tests) — PASS
- sensor_data_reconciler_test.dart (3 tests) — PASS
- heart_rate_parser_test.dart (12 tests) — PASS
- esp32_adapter_test.dart (7 tests) — PASS
- 	win_sensor_coordinator_test.dart (2 tests) — PASS

### 3.2 Flutter Code Quality
Ran lutter analyze --no-pub:
- **0 issues found!** Clean analysis across the entire project.

### 3.3 Backend TWIN & Regression Suite
Ran pytest:
- Behavioral & Hardware Signals suite: **31 passed**
- Legacy RecoveryState & Phase 12 suite: **22 passed**

---

## 4. Physical Phone Verification Guide

When testing on an Android device:
1. **Launch App**: Run lutter run -d <deviceId> from continuum-health/bang_lore-main.
2. **Open Sensor Diagnostics**: Navigate to TWIN Center and tap 'Sensor Diagnostics'.
3. **Stationary Verification**: Place phone flat on table. Verify \$\approx 20\text{--}50\ \text{Hz}\$, Total Accel \$\approx 9.81\ m/s^2\$, Gyroscope \$\approx 0.0\ \text{rad/s}\$, steps = 0, activity = STATIONARY.
4. **Rotational Suppression Verification**: Rotate/twist phone in hand. Verify Gyroscope spikes (\$>\ 2.5\ \text{rad/s}\$), steps remain 0.
5. **Walking Verification**: Walk 20 steps. Verify steps increment in real-time and activity transitions to WALKING.
