import 'dart:io';

import 'package:health/health.dart';

import 'health_service.dart';

class PlatformHealthService implements HealthService {
  final Health _health = Health();
  bool _configured = false;

  // Health Connect has no mindfulness type in the plugin, so Android reads workouts only.
  List<HealthDataType> get _types =>
      Platform.isIOS ? const [HealthDataType.WORKOUT, HealthDataType.MINDFULNESS] : const [HealthDataType.WORKOUT];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS;

  @override
  String get storeName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  Future<bool> requestAccess() async {
    if (!supported) return false;
    await _configure();
    if (Platform.isAndroid) {
      final status = await _health.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        await _health.installHealthConnect();
        return false;
      }
    }
    final types = _types;
    return _health.requestAuthorization(types, permissions: types.map((_) => HealthDataAccess.READ).toList());
  }

  @override
  Future<List<HealthSession>> sessionsSince(DateTime since) async {
    if (!supported) return const [];
    await _configure();
    final points = await _health.getHealthDataFromTypes(types: _types, startTime: since, endTime: DateTime.now());
    final sessions = <HealthSession>[];
    for (final p in points) {
      final isWorkout = p.type == HealthDataType.WORKOUT;
      final value = p.value;
      sessions.add(HealthSession(
        id: p.uuid,
        kind: isWorkout ? 'WORKOUT' : 'MINDFUL',
        title: isWorkout && value is WorkoutHealthValue ? _prettyWorkout(value.workoutActivityType) : 'Mindful minutes',
        start: p.dateFrom,
        end: p.dateTo,
      ));
    }
    return sessions;
  }

  /// RUNNING_TREADMILL -> "Running treadmill"
  String _prettyWorkout(HealthWorkoutActivityType type) {
    if (type == HealthWorkoutActivityType.OTHER) return 'Workout';
    final words = type.name.toLowerCase().replaceAll('_', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }
}
