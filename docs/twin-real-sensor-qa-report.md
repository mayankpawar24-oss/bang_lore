# Continuum Health — Final TWIN Real Hardware Sensor Engineering & QA Report

## 1. Original Root Cause
The user-visible symptom was that in the mobile application:
- Steps remained static at 0 or failed to accumulate during physical walking.
- Activity classification remained UNKNOWN or defaulted to a misleading Stationary state.
- Sensor data did not appear to update the TWIN state on screen.

## 2. Exact Source of the Zero-Step / No-Activity Bug
Through forensic instrumentation and stack tracing from native Android up to Flutter UI, seven compounding root causes were identified and eliminated:

1. **Hardware Ingestion Delay (5 Hz Aliasing)**: PhoneMotionPipeline requested SensorInterval.normalInterval (200 ms per sample = 5 Hz). Human walking cadence spans 1.5 to 3.5 Hz (steps every 300–600 ms). At 5 Hz, Nyquist frequency is 2.5 Hz; step peaks and valleys were missed or aliased into low-amplitude noise.
2. **Step Detector Threshold Floor Over-Tuned**: AdaptivePeakValleyStepCounter had a minimum dynamic swing threshold of 1.4 m/s² and dynamic peak floor of 0.6 m/s². Normal walking with the phone in pocket or gentle hand-holding produces swings of 0.85–1.2 m/s², causing all valid footsteps to be rejected as 'insufficient swing'.
3. **Activity Windowing Latency & Tumbling Flush**: ActivityRecognitionService operated on non-overlapping tumbling windows of 50 samples with _sampleWindow.clear(). At low frequency, this required >20 seconds of unbroken motion before the 2-window hysteresis could trigger WALKING.
4. **Disconnected Cadence Pipeline**: PedometerService computed dynamic cadence from peak intervals but never transmitted it to ActivityRecognitionService. Consequently, ActivityRecognitionService._currentCadence remained permanently 0.0, blinding the classifier to cadence evidence.
5. **Session Step vs Daily Baseline Reconciler Discrepancy**: PedometerService emitted session steps as isCumulative: true. When re-opening the app or having existing steps, any session count below the historical daily total was rejected by SensorDataReconciler.
6. **Static UI Never Listening to Live Sensor Notifiers**: In TwinCenterScreen, _buildTelemetryGrid only read static values from _twinState fetched once on screen load; it never listened to currentStepsNotifier or currentActivityNotifier.
7. **Runtime Permission Blocking on Android 10+**: ACTIVITY_RECOGNITION and HIGH_SAMPLING_RATE_SENSORS were missing from the pipeline's runtime permission check, causing high-rate hardware sensor throttling and native step sensor blocking.

---

## 3. Sensor Acquisition Architecture

`	ext
PHYSICAL PHONE SENSORS (Accelerometer + Gyroscope)
                  ↓
       Android SensorManager / iOS CoreMotion (50 Hz)
                  ↓
       PhoneMotionPipeline (sensors_plus @ gameInterval)
                  ↓
       EMA Low-Pass Gravity Separation (α = 0.80)
                  ↓
  ┌───────────────────────────────┴───────────────────────────────┐
  ↓                                                               ↓
AdaptivePeakValleyStepCounter                     ActivityRecognitionService
- 50 Hz Sliding Window                            - 50-Sample Rolling Window (1s)
- Peak/Valley Adaptive Thresholds                 - 10-Sample Sliding Hop (200ms)
- Dynamic Swing >= 0.85 m/s²                      - Accel Variance, RMS, User Mag
- Gyro Rotational Suppression (> 2.5 rad/s)       - Cadence Fusion from Step Counter
- Real-Time Cadence Calculation                   - 2-Stage Hysteresis State Machine
  │                                               - Crosswalk Pause Debounce (4s)
  └───────────────────────────────┬───────────────────────────────┘
                                  ↓
                        TwinSensorCoordinator
                     (Riverpod Singleton Provider)
                                  ↓
                        SensorDataReconciler
               - Daily Baseline Seeding from TWIN State
               - 1-Step Delta Accumulator
               - Multi-Source Precedence (BLE > HealthKit > Phone)
                                  ↓
  ┌───────────────────────────────┴───────────────────────────────┐
  ↓                                                               ↓
Live Notifiers (Zero-Latency UI Rebuild)        Signal Buffer & Sync Engine
- currentStepsNotifier                         - Flush every 15s to /twin/signals
- currentActivityNotifier                      - Offline Queue Resilience
- diagnosticsNotifier                          - Backend Closed-Loop Evaluator
  │                                                               │
  └───────────────────────────────┬───────────────────────────────┘
                                  ↓
               TwinActivityCard & TwinCenterScreen
               - Live Step & Activity Tiles
               - Phone IMU Live Frequency Pill
               - Collapsible Sensor Diagnostics Sheet
               - 7-Stage Explainable Decision Trace
`

---

## 4. Platform Implementation Details

### 4.1 Android Implementation
- **Sensors**: Hardware Sensor.TYPE_ACCELEROMETER and Sensor.TYPE_GYROSCOPE.
- **Sampling Rate**: SensorInterval.gameInterval (50 Hz / 20 ms interval).
- **Manifest Permissions**:
  - ndroid.permission.ACTIVITY_RECOGNITION
  - ndroid.permission.BODY_SENSORS
  - ndroid.permission.HIGH_SAMPLING_RATE_SENSORS
- **Runtime Flow**: On start(), PhoneMotionPipeline.requestPermissions() verifies and requests Permission.activityRecognition.

### 4.2 iOS Implementation
- **Sensors**: CMMotionManager streaming accelerometer and gyroscope at 50 Hz.
- **Usage Descriptions**: Configured in Info.plist with NSMotionUsageDescription.
- **Lifecycle**: Streams cleanly pause on application background and resume on foreground.

### 4.3 Web Limitations
- Web browsers generally do not grant low-level raw 50 Hz accelerometer or gyroscope stream access without specific device orientation events on HTTPS.
- In accordance with architectural rules, Web builds gracefully show Phone IMU: Sensor Standby / Web Environment and DO NOT inject synthetic or mock sensor values.

---

## 5. Algorithmic Specifications

### 5.1 Gravity Separation (Low-Pass EMA Filter)
\mathbf{g}_t = \alpha \cdot \mathbf{g}_{t-1} + (1 - \alpha) \cdot \mathbf{a}_{\text{raw}, t} \quad (\alpha = 0.80)
\mathbf{a}_{\text{user}, t} = \mathbf{a}_{\text{raw}, t} - \mathbf{g}_t

### 5.2 Adaptive Peak/Valley Step Detection
- **Magnitude Filtering**: $\alpha_{\text{smooth}} = 0.22$ on Euclidean acceleration norm $\|\mathbf{a}\| = \sqrt{a_x^2 + a_y^2 + a_z^2}$.
- **Sliding History**: 50 samples (1.0 s at 50 Hz) computing running $\mu$ and $[\min, \max]$.
- **Dynamic Thresholds**:
  - $\Delta_{\text{peak}} = \max(0.35, 0.28 \cdot (\max - \mu))$
  - $\Delta_{\text{valley}} = \max(0.35, 0.28 \cdot (\mu - \min))$
  - Peak threshold: {\text{peak}} = \mu + \Delta_{\text{peak}}$
  - Valley threshold: {\text{valley}} = \mu - \Delta_{\text{valley}}$
- **Refractory Timing**: $\Delta t \in [220\ \text{ms}, 2000\ \text{ms}]$ (limits cadence to \text{--}270\ \text{steps/min}$).
- **Rotational False-Positive Suppression**: If $\|\boldsymbol{\omega}\| > 2.5\ \text{rad/s}$ and dynamic swing $< 2.5\ m/s^2$, candidate step is rejected.

### 5.3 Sliding-Window Activity Recognition
- **Window Size**: 50 samples (1.0 second).
- **Hop Size**: 10 samples (200 ms advance, 80% overlap).
- **Cadence Integration**: Fed in real-time from AdaptivePeakValleyStepCounter.cadenceEstimate.
- **Hysteresis State Machine**: 2 consecutive matching windows required for state transition.
- **Crosswalk Pause Debounce**: 4-second hold on WALKING when stepping stops before falling back to STATIONARY.

---

## 6. Comprehensive Verification Matrix

| Verification Scope | Execution Target | Outcome | Status |
| :--- | :--- | :--- | :--- |
| **Adaptive Step Counter Algorithm** | 12 unit tests (refractory, pause recovery, rotation suppression) | 12/12 Passed | PASS — SYNTHETIC FIXTURE |
| **Activity Classification Hysteresis** | 5 unit tests (walking, running, automotive, platform) | 5/5 Passed | PASS — SYNTHETIC FIXTURE |
| **Phone Motion Pipeline Magnitudes** | 3 unit tests (3D norms, EMA gravity separation, Hz estimator) | 3/3 Passed | PASS — SYNTHETIC FIXTURE |
| **Sensor Reconciler & Deduplication** | 3 unit tests (precedence, day rollover, delta accumulators) | 3/3 Passed | PASS — SYNTHETIC FIXTURE |
| **Heart Rate SIG 0x2A37 Parser** | 12 unit tests (8-bit, 16-bit, RR intervals, energy expended) | 12/12 Passed | PASS — SYNTHETIC FIXTURE |
| **ESP32 GATT Climate Parser** | 7 unit tests (temp, humidity, ASCII, JSON, malformed) | 7/7 Passed | PASS — SYNTHETIC FIXTURE |
| **Twin Sensor Coordinator Queue** | 2 unit tests (reactive notifiers, offline queue lifecycle) | 2/2 Passed | PASS — SYNTHETIC FIXTURE |
| **Full Sensors Test Suite** | lutter test test/sensors/ (44 test cases total) | 44/44 Passed | PASS — SYNTHETIC FIXTURE |
| **Flutter Static Analysis** | lutter analyze --no-pub | 0 issues found | PASS — REAL CODEBASE |
| **Backend TWIN Behavioral Engine** | pytest tests/unit/twin/ ... (31 test cases) | 31/31 Passed | PASS — SYNTHETIC FIXTURE |
| **Backend RecoveryState Regression** | pytest tests/integration/test_twin_api.py ... (22 test cases) | 22/22 Passed | PASS — SYNTHETIC FIXTURE |
| **Physical Phone Installation** | AEZPMZIFKZ4HBES8 (Realme 12 5G / RMX3870) | Streamed Install Success | PASS — REAL HARDWARE |
| **Port Forwarding Connectivity** | db reverse tcp:8000 tcp:8000 | Active on device | PASS — REAL HARDWARE |
| **Physical Sensor Streaming (Table)** | Phone still on flat surface: 0 steps, STATIONARY, ~50 Hz | Verified in telemetry | PASS — REAL HARDWARE |
| **Physical Rotation Suppression** | Phone twisting/rotation in hand: steps remain 0, gyro > 2.5 rad/s | Verified in telemetry | PASS — REAL HARDWARE |
| **Physical Walking Test (100 steps)** | User walking with phone: steps increment, activity WALKING | Ready for physical test | REQUIRES USER TRIAL |

---

## 7. Closed-Loop Telemetry & Decision Trace Integration
When the user receives a proactive TWIN recommendation (e.g. Take a brisk 10-minute walk):
1. User clicks **Accept**.
2. Recommendation state moves to ACCEPTED.
3. User physically walks with their phone.
4. PhoneMotionPipeline feeds 50 Hz motion data to AdaptivePeakValleyStepCounter and ActivityRecognitionService.
5. Steps increment in real-time on TwinActivityCard and TwinCenterScreen.
6. Activity switches to WALKING.
7. TwinSensorCoordinator.flushQueue() posts normalized signals to /twin/signals.
8. Backend evaluate_closed_loop_outcome detects current_activity == WALKING and marks recommendation COMPLETED with effectiveness score  .95.
9. TwinBehavioralMemory increments 	otal_recommendations_completed and updates user routine learning.
10. The 7-Stage Decision Trace sheet renders the real sensor outcome without any mock data.
