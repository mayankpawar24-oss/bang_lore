import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'twin_sensor_coordinator.dart';

/// App-wide singleton provider for the [TwinSensorCoordinator].
///
/// Ensures a single persistent coordinator handles hardware sensor streams across
/// screen navigations (Dashboard <-> TWIN Center <-> Details), preventing duplicate
/// listeners, stream cancellations, and memory leaks.
final twinSensorCoordinatorProvider =
    Provider.family<TwinSensorCoordinator, String>((ref, patientId) {
  final effectivePatientId =
      patientId.isNotEmpty ? patientId : 'dev-token-patient-alex';
  final backend = ref.watch(backendServiceProvider);

  final coordinator = TwinSensorCoordinator(
    patientId: effectivePatientId,
    backendService: backend,
  );
  coordinator.initialize();

  ref.onDispose(() {
    coordinator.dispose();
  });

  return coordinator;
});
