import 'health_service.dart';

/// Web and desktop have no health store.
class PlatformHealthService implements HealthService {
  @override
  bool get supported => false;

  @override
  String get storeName => 'Health';

  @override
  Future<bool> requestAccess() async => false;

  @override
  Future<List<HealthSession>> sessionsSince(DateTime since) async => const [];
}
