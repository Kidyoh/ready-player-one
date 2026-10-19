import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Single source of truth for the signed-in player. Screens read from it and call its actions;
/// every action that changes XP refreshes the character so bars and levels stay in sync.
class AppState extends ChangeNotifier {
  AppState(this.api);

  static const _tokenKey = 'auth_token';

  final Api api;
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
  }

  Future<void> _startSession(String token, Character character) async {
    api.token = token;
    me = character;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await refreshAll();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final results = await Future.wait([api.me(), api.activities(), api.quests(), api.party()]);
    me = results[0] as Character;
    activities = results[1] as List<Activity>;
    quests = results[2] as List<Quest>;
    party = results[3] as Party?;
    feed = party == null ? [] : await api.feed();
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
