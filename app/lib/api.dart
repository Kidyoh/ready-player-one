import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Base URL comes from `--dart-define=API_URL=...`. The Android emulator reaches the
/// host machine via 10.0.2.2; everything else defaults to localhost.
String defaultBaseUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080';
  return 'http://localhost:8080';
}

class Api {
  Api({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl(),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? token;

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req));
    } catch (_) {
      throw ApiException(0, "Can't reach the server at $baseUrl");
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final message = decoded is Map && decoded['error'] is String ? decoded['error'] as String : 'Request failed';
      throw ApiException(res.statusCode, message);
    }
    return decoded;
  }

  // Auth
  Future<(String, Character)> register(String email, String password, String displayName, String avatar) async {
    final j = await _send('POST', '/auth/register',
        {'email': email, 'password': password, 'displayName': displayName, 'avatar': avatar});
    return (j['token'] as String, Character.fromJson(j['user'] as Map<String, dynamic>));
  }

  Future<(String, Character)> login(String email, String password) async {
    final j = await _send('POST', '/auth/login', {'email': email, 'password': password});
    return (j['token'] as String, Character.fromJson(j['user'] as Map<String, dynamic>));
  }

  // Character
  Future<Character> me() async => Character.fromJson(await _send('GET', '/me') as Map<String, dynamic>);

  Future<Character> updateMe({String? displayName, String? avatar}) async => Character.fromJson(await _send(
      'PATCH', '/me', {'displayName': ?displayName, 'avatar': ?avatar}) as Map<String, dynamic>);

  // Activities
  Future<List<Activity>> activities() async =>
      (await _send('GET', '/activities?limit=100') as List).map((a) => Activity.fromJson(a as Map<String, dynamic>)).toList();

  Future<LogResult> logActivity(Category category, String title, int minutes, String? note) async =>
      LogResult.fromJson(await _send('POST', '/activities', {
        'category': category.api,
        'title': title,
        'minutes': minutes,
        if (note != null && note.isNotEmpty) 'note': note,
      }) as Map<String, dynamic>);

  Future<void> deleteActivity(String id) => _send('DELETE', '/activities/$id');

  // Quests
  Future<List<Quest>> quests() async =>
      (await _send('GET', '/quests') as List).map((q) => Quest.fromJson(q as Map<String, dynamic>)).toList();

  Map<String, Object> _goalBody(String goal, Category category, int weeks, int sessions, int minutes, bool forParty) => {
        'goal': goal,
        'category': category.api,
        'weeks': weeks,
        'sessionsPerWeek': sessions,
        'minutesPerSession': minutes,
        'forParty': forParty,
      };

  Future<QuestPreview> previewQuest(String goal, Category category, int weeks, int sessions, int minutes) async =>
      QuestPreview.fromJson(await _send('POST', '/quests/preview', _goalBody(goal, category, weeks, sessions, minutes, false))
          as Map<String, dynamic>);

  Future<Quest> questFromGoal(String goal, Category category, int weeks, int sessions, int minutes, bool forParty) async =>
      Quest.fromJson(await _send('POST', '/quests/from-goal', _goalBody(goal, category, weeks, sessions, minutes, forParty))
          as Map<String, dynamic>);

  Future<Quest> completeStep(String questId, String stepId) async {
    final j = await _send('POST', '/quests/$questId/steps/$stepId/complete');
    return Quest.fromJson(j['quest'] as Map<String, dynamic>);
  }

  Future<Quest> abandonQuest(String id) async =>
      Quest.fromJson(await _send('POST', '/quests/$id/abandon') as Map<String, dynamic>);

  // Party
  Party? _partyOf(dynamic j) => j['party'] == null ? null : Party.fromJson(j['party'] as Map<String, dynamic>);

  Future<Party?> party() async => _partyOf(await _send('GET', '/party'));
  Future<Party?> createParty(String name) async => _partyOf(await _send('POST', '/party', {'name': name}));
  Future<Party?> joinParty(String code) async => _partyOf(await _send('POST', '/party/join', {'code': code}));
  Future<void> leaveParty() => _send('POST', '/party/leave');

  Future<List<FeedEvent>> feed() async =>
      (await _send('GET', '/party/feed') as List).map((e) => FeedEvent.fromJson(e as Map<String, dynamic>)).toList();

  Future<void> cheer(String eventId) => _send('POST', '/party/feed/$eventId/cheer');

  // Integrations
  Future<(IntegrationStatus, IntegrationStatus)> integrations() async {
    final j = await _send('GET', '/integrations') as Map<String, dynamic>;
    return (
      IntegrationStatus.fromJson(j['github'] as Map<String, dynamic>),
      IntegrationStatus.fromJson(j['health'] as Map<String, dynamic>),
    );
  }

  Future<SyncSummary> connectGitHubToken(String token) async {
    final j = await _send('POST', '/integrations/github/token', {'token': token});
    return SyncSummary.fromJson(j['sync'] as Map<String, dynamic>);
  }

  Future<DeviceFlow> startGitHubDeviceFlow() async =>
      DeviceFlow.fromJson(await _send('POST', '/integrations/github/device/start') as Map<String, dynamic>);

  /// Returns null while the user hasn't approved yet; throws if the code expired or was denied.
  Future<SyncSummary?> pollGitHubDeviceFlow(String deviceCode) async {
    final j = await _send('POST', '/integrations/github/device/poll', {'deviceCode': deviceCode}) as Map<String, dynamic>;
    return switch (j['status']) {
      'connected' => SyncSummary.fromJson(j['sync'] as Map<String, dynamic>),
      'pending' || 'slow_down' => null,
      'denied' => throw ApiException(400, 'GitHub access was denied'),
      _ => throw ApiException(400, 'The GitHub code expired. Try again.'),
    };
  }

  Future<SyncSummary> syncGitHub() async =>
      SyncSummary.fromJson(await _send('POST', '/integrations/github/sync') as Map<String, dynamic>);

  Future<void> disconnectGitHub() => _send('DELETE', '/integrations/github');

  Future<SyncSummary> importHealth(String device, List<Map<String, Object>> sessions) async => SyncSummary.fromJson(
      await _send('POST', '/integrations/health/import', {'device': device, 'sessions': sessions}) as Map<String, dynamic>);

  Future<void> disconnectHealth() => _send('DELETE', '/integrations/health');
}
