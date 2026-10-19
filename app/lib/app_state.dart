import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'integrations/health_service.dart';
import 'models.dart';

/// Single source of truth for the signed-in player. Screens read from it and call its actions;
/// every action that changes XP refreshes the character so bars and levels stay in sync.
class AppState extends ChangeNotifier {
  AppState(this.api, {HealthService? health}) : health = health ?? HealthService();

  static const _tokenKey = 'auth_token';

  final Api api;
  final HealthService health;
  IntegrationStatus github = const IntegrationStatus.disconnected();
  IntegrationStatus healthStatus = const IntegrationStatus.disconnected();
  bool syncing = false;

  /// One-off messages for the shell to toast, e.g. results of a background sync.
  final ValueNotifier<String?> notices = ValueNotifier(null);
  bool booting = true;
  Character? me;
  List<Activity> activities = [];
  List<Quest> quests = [];
  Party? party;
  List<FeedEvent> feed = [];

  bool get signedIn => me != null;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString(_tokenKey);
    if (api.token != null) {
      try {
        await refreshAll();
      } on ApiException catch (e) {
        if (e.statusCode == 401) await signOut();
      }
    }
    booting = false;
    notifyListeners();
    if (signedIn) unawaited(syncAll());
  }

  Future<void> _startSession(String token, Character character) async {
    api.token = token;
    me = character;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await refreshAll();
    unawaited(syncAll());
  }

  Future<void> signIn(String email, String password) async {
    final (token, character) = await api.login(email, password);
    await _startSession(token, character);
  }

  Future<void> signUp(String email, String password, String name, String avatar) async {
    final (token, character) = await api.register(email, password, name, avatar);
    await _startSession(token, character);
  }

  Future<void> signOut() async {
    api.token = null;
    me = null;
    activities = [];
    quests = [];
    party = null;
    feed = [];
    github = const IntegrationStatus.disconnected();
    healthStatus = const IntegrationStatus.disconnected();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final results = await Future.wait([api.me(), api.activities(), api.quests(), api.party(), api.integrations()]);
    me = results[0] as Character;
    activities = results[1] as List<Activity>;
    quests = results[2] as List<Quest>;
    party = results[3] as Party?;
    final (gh, hs) = results[4] as (IntegrationStatus, IntegrationStatus);
    github = gh;
    healthStatus = hs;
    feed = party == null ? [] : await api.feed();
    notifyListeners();
  }

  // ---- Integrations ----

  /// Pulls from every connected source. Runs on launch and whenever the app comes back to the foreground.
  Future<void> syncAll() async {
    if (!signedIn || syncing) return;
    syncing = true;
    notifyListeners();
    final gained = <String>[];
    var xp = 0;
    try {
      if (github.connected) {
        final s = await api.syncGitHub();
        if (s.changed) gained.add('GitHub');
        xp += s.xpGained;
      }
      if (healthStatus.connected && health.supported) {
        final s = await _importHealth();
        if (s.changed) gained.add(health.storeName);
        xp += s.xpGained;
      }
      if (gained.isNotEmpty) {
        await refreshAll();
        notices.value = 'Synced ${gained.join(' & ')} · +$xp XP';
      }
    } on ApiException catch (e) {
      notices.value = e.message;
    } catch (_) {
      // Health stores can throw platform errors (permission revoked etc.); the next sync will retry.
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<SyncSummary> _importHealth() async {
    final since = (healthStatus.lastSyncedAt ?? DateTime.now().subtract(const Duration(days: 7)))
        .subtract(const Duration(days: 1));
    final sessions = await health.sessionsSince(since);
    return api.importHealth(health.storeName, sessions.map((s) => s.toJson()).toList());
  }

  /// Returns null when the user declined access or the health store isn't available.
  Future<SyncSummary?> connectHealth() async {
    if (!await health.requestAccess()) return null;
    final summary = await _importHealth();
    await refreshAll();
    return summary;
  }

  Future<void> disconnectHealth() async {
    await api.disconnectHealth();
    await refreshAll();
  }

  Future<SyncSummary> connectGitHubToken(String token) async {
    final summary = await api.connectGitHubToken(token);
    await refreshAll();
    return summary;
  }

  /// Polls until the user approves on github.com, the code expires, or [cancelled] returns true.
  Future<SyncSummary?> finishGitHubDeviceFlow(DeviceFlow flow, bool Function() cancelled) async {
    var interval = Duration(seconds: flow.interval);
    final deadline = DateTime.now().add(Duration(seconds: flow.expiresIn));
    while (!cancelled() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      if (cancelled()) return null;
      final summary = await api.pollGitHubDeviceFlow(flow.deviceCode);
      if (summary != null) {
        await refreshAll();
        return summary;
      }
      interval += const Duration(seconds: 1); // be gentle, GitHub asks for this on slow_down
    }
    return null;
  }

  Future<void> disconnectGitHub() async {
    await api.disconnectGitHub();
    await refreshAll();
  }

  Future<void> toggleCheer(FeedEvent event) async {
    await api.cheer(event.id);
    feed = await api.feed();
    notifyListeners();
  }

  Future<void> updateProfile({String? displayName, String? avatar}) async {
    me = await api.updateMe(displayName: displayName, avatar: avatar);
    notifyListeners();
  }

  Future<LogResult> logActivity(Category category, String title, int minutes, String? note) async {
    final result = await api.logActivity(category, title, minutes, note);
    await refreshAll();
    return result;
  }

  Future<void> deleteActivity(Activity activity) async {
    activities = activities.where((a) => a.id != activity.id).toList();
    notifyListeners();
    await api.deleteActivity(activity.id);
    await refreshAll();
  }

  Future<Quest> createQuest(String goal, Category category, int weeks, int sessions, int minutes, bool forParty) async {
    final quest = await api.questFromGoal(goal, category, weeks, sessions, minutes, forParty);
    await refreshAll();
    return quest;
  }

  Future<Quest> completeStep(Quest quest, QuestStep step) async {
    final updated = await api.completeStep(quest.id, step.id);
    await refreshAll();
    return updated;
  }

  Future<void> abandonQuest(Quest quest) async {
    await api.abandonQuest(quest.id);
    await refreshAll();
  }

  Future<void> createParty(String name) async {
    party = await api.createParty(name);
    await refreshAll();
  }

  Future<void> joinParty(String code) async {
    party = await api.joinParty(code);
    await refreshAll();
  }

  Future<void> leaveParty() async {
    await api.leaveParty();
    await refreshAll();
  }

  Quest? questById(String id) {
    for (final q in quests) {
      if (q.id == id) return q;
    }
    return null;
  }
}
