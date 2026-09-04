import 'package:flutter_test/flutter_test.dart';
import 'package:continuum_health/data/models/twin_state_model.dart';

void main() {
  group('TWIN Behavioral Intelligence & Decision Trace Models', () {
    test('TwinBehaviorPatternModel serializes and deserializes properly', () {
      final json = {
        'pattern_id': 'pat_001',
        'pattern_type': 'TIMING_ACCEPTANCE',
        'description': 'User accepts suggestions around 14:00',
        'confidence': 0.85,
        'support_count': 4,
        'time_window_start_hour': 14,
        'time_window_end_hour': 16,
        'acceptance_rate': 0.9,
      };

      final pattern = TwinBehaviorPatternModel.fromJson(json);
      expect(pattern.patternId, 'pat_001');
      expect(pattern.patternType, 'TIMING_ACCEPTANCE');
      expect(pattern.confidence, 0.85);
      expect(pattern.supportCount, 4);
      expect(pattern.timeWindowStartHour, 14);
      expect(pattern.timeWindowEndHour, 16);
      expect(pattern.acceptanceRate, 0.9);
    });

    test('TwinBehavioralMemoryModel computes rates correctly', () {
      final memory = TwinBehavioralMemoryModel(
        patientId: 'patient_001',
        totalRecommendationsCreated: 10,
        totalRecommendationsAccepted: 6,
        totalRecommendationsDismissed: 2,
        totalRecommendationsCompleted: 5,
        preferredHours: const [14, 15],
      );

      // Acceptance: 6 / (6 + 2) = 0.75
      expect(memory.acceptanceRate, 0.75);
      // Completion: 5 / 6 = 0.83
      expect(memory.completionRate, 0.83);
    });

    test('TwinDecisionTraceModel parses all 7-stage explanation fields', () {
      final json = {
        'trace_id': 'trace_123',
        'recommendation_id': 'rec_456',
        'patient_id': 'patient_001',
        'timestamp': '2026-09-05T14:00:00Z',
        'observed_signals': {
          'activity': 'STATIONARY',
          'duration_minutes': 75,
          'heart_rate': 74.0,
          'spo2': 98.0,
          'temperature': 27.5,
        },
        'care_context': {
          'recovery_trajectory': 'STABLE',
          'active_medications': ['Lisinopril 10mg'],
        },
        'why_now': 'Context evaluated: OPPORTUNITY_OPTIMAL.',
        'decision': 'Short gentle walk recommended.',
        'action_prompt': 'Time for a quick stretch.',
        'expected_outcome': 'Movement within 30 minutes.',
        'outcome_observed': 'Behavior verified: WALKING detected.',
        'learning_delta': 'Behavioral score: 0.9. Habit reinforced.',
      };

      final trace = TwinDecisionTraceModel.fromJson(json);
      expect(trace.traceId, 'trace_123');
      expect(trace.recommendationId, 'rec_456');
      expect(trace.observedSignals['activity'], 'STATIONARY');
      expect(trace.observedSignals['spo2'], 98.0);
      expect(trace.careContext['recovery_trajectory'], 'STABLE');
      expect(trace.outcomeObserved, contains('WALKING'));
      expect(trace.learningDelta, contains('Habit reinforced'));
    });

    test('TwinStateModel parses nested behavioral memory, care context, and trace', () {
      final json = {
        'patient_id': 'patient_001',
        'updated_at': '2026-09-05T14:00:00Z',
        'activity_summary': {
          'current_activity': 'STATIONARY',
          'current_duration_minutes': 75,
          'steps_today': 1200,
          'step_goal': 6000,
        },
        'latest_health_signals': {
          'heart_rate': {
            'metric': 'heart_rate',
            'value': 74.0,
            'unit': 'bpm',
            'timestamp': '2026-09-05T14:00:00Z',
            'source': 'BLE',
          },
          'spo2': {
            'metric': 'spo2',
            'value': 98.0,
            'unit': '%',
            'timestamp': '2026-09-05T14:00:00Z',
            'source': 'BLE',
          },
          'temperature': {
            'metric': 'temperature',
            'value': 27.8,
            'unit': '°C',
            'timestamp': '2026-09-05T14:00:00Z',
            'source': 'ESP32',
          },
          'humidity': {
            'metric': 'humidity',
            'value': 55.0,
            'unit': '%',
            'timestamp': '2026-09-05T14:00:00Z',
            'source': 'ESP32',
          },
        },
        'baselines': {
          'resting_heart_rate': 72.0,
          'sample_count': 10,
          'completeness': 'ROBUST',
        },
        'care_context': {
          'recovery_trajectory': 'STABLE',
          'active_medications': ['Amlodipine 5mg'],
        },
        'behavioral_memory': {
          'patient_id': 'patient_001',
          'total_recommendations_accepted': 5,
          'total_recommendations_completed': 5,
        },
        'active_recommendations': [],
        'recent_user_reported_states': ['FATIGUE'],
      };

      final state = TwinStateModel.fromJson(json);
      expect(state.patientId, 'patient_001');
      expect(state.heartRate, 74.0);
      expect(state.spo2, 98.0);
      expect(state.temperature, 27.8);
      expect(state.humidity, 55.0);
      expect(state.careContext?.recoveryTrajectory, 'STABLE');
      expect(state.behavioralMemory?.totalRecommendationsAccepted, 5);
      expect(state.recentUserReportedStates, contains('FATIGUE'));
    });
  });
}
