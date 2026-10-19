import 'health_service_stub.dart' if (dart.library.io) 'health_service_io.dart' as impl;

/// One exercise or mindfulness session read from the phone's health store.
class HealthSession {
  const HealthSession({required this.id, required this.kind, required this.title, required this.start, required this.end});

  final String id;
  final String kind; // WORKOUT | MINDFUL
  final String title;
  final DateTime start;
  final DateTime end;

  Map<String, Object> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      };
}

/// Reads sessions from Health Connect (Android) or Apple Health (iOS). Unsupported elsewhere.
abstract class HealthService {
  factory HealthService() = impl.PlatformHealthService;

  bool get supported;

  /// "Health Connect" or "Apple Health".
  String get storeName;

  /// Asks for read access. Returns false if the user declines or the store isn't installed.
  Future<bool> requestAccess();

  Future<List<HealthSession>> sessionsSince(DateTime since);
}
