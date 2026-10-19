import 'package:flutter/material.dart';

import 'theme.dart';

enum Category {
  workout('WORKOUT', 'Workout', 'workouts', 'Strength', Icons.fitness_center, Color(0xFFE8734A)),
  reading('READING', 'Reading', 'reading', 'Intellect', Icons.menu_book_rounded, Color(0xFF4F8FD6)),
  coding('CODING', 'Coding', 'coding', 'Craft', Icons.code_rounded, Color(0xFF3FA38F)),
  mindful('MINDFUL', 'Mindful', 'mindfulness', 'Spirit', Icons.self_improvement, Color(0xFFA07AD0));

  const Category(this.api, this.label, this.practice, this.stat, this.icon, this.color);
  final String api;
  final String label;

  /// Lowercase noun for sentences like "from workouts" or "30 min of mindfulness".
  final String practice;
  final String stat;
  final IconData icon;
  final Color color;

  static Category fromApi(String v) => values.firstWhere((c) => c.api == v);
}

class LevelProgress {
  LevelProgress.fromJson(Map<String, dynamic> j)
      : level = j['level'] as int,
        xp = j['xp'] as int,
        xpIntoLevel = j['xpIntoLevel'] as int,
        xpForNextLevel = j['xpForNextLevel'] as int;

  final int level;
  final int xp;
  final int xpIntoLevel;
  final int xpForNextLevel;

  double get fraction => xpForNextLevel == 0 ? 0 : xpIntoLevel / xpForNextLevel;
}

class Stat {
  Stat.fromJson(Map<String, dynamic> j)
      : category = Category.fromApi(j['category'] as String),
        progress = LevelProgress.fromJson(j);

  final Category category;
  final LevelProgress progress;
}

/// A player as seen by party members.
class Player {
  Player.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        displayName = j['displayName'] as String,
        avatar = j['avatar'] as String,
        level = j['level'] as int,
        title = j['title'] as String,
        totalXp = j['totalXp'] as int,
        currentStreak = j['currentStreak'] as int,
        isLeader = j['isLeader'] as bool? ?? false;

  final String id;
  final String displayName;
  final String avatar;
  final int level;
  final String title;
  final int totalXp;
  final int currentStreak;
  final bool isLeader;
}

class Character extends Player {
  Character.fromJson(super.j)
      : email = j['email'] as String,
        longestStreak = j['longestStreak'] as int,
        progress = LevelProgress.fromJson(j['progress'] as Map<String, dynamic>),
        stats = (j['stats'] as List).map((s) => Stat.fromJson(s as Map<String, dynamic>)).toList(),
        super.fromJson();

  final String email;
  final int longestStreak;
  final LevelProgress progress;
  final List<Stat> stats;
}

class Activity {
  Activity.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        category = Category.fromApi(j['category'] as String),
        title = j['title'] as String,
        minutes = j['minutes'] as int,
        note = j['note'] as String?,
        xp = j['xp'] as int,
        createdAt = DateTime.parse(j['createdAt'] as String).toLocal();

  final String id;
  final Category category;
  final String title;
  final int minutes;
  final String? note;
  final int xp;
  final DateTime createdAt;
}

class MiniUser {
  MiniUser.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        displayName = j['displayName'] as String,
        avatar = j['avatar'] as String;

  final String id;
  final String displayName;
  final String avatar;
}

class QuestStep {
  QuestStep.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        position = j['position'] as int,
        title = j['title'] as String,
        targetMinutes = j['targetMinutes'] as int,
        completedAt = j['completedAt'] == null ? null : DateTime.parse(j['completedAt'] as String).toLocal(),
        completedBy = j['completedBy'] == null ? null : MiniUser.fromJson(j['completedBy'] as Map<String, dynamic>);

  final String id;
  final int position;
  final String title;
  final int targetMinutes;
  final DateTime? completedAt;
  final MiniUser? completedBy;

  bool get done => completedAt != null;
  bool get isBoss => targetMinutes == 0;
}

enum QuestStatus { active, completed, abandoned }

class Quest {
  Quest.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        goal = j['goal'] as String?,
        category = Category.fromApi(j['category'] as String),
        status = QuestStatus.values.byName((j['status'] as String).toLowerCase()),
        rewardXp = j['rewardXp'] as int,
        isParty = j['partyId'] != null,
        dueAt = j['dueAt'] == null ? null : DateTime.parse(j['dueAt'] as String).toLocal(),
        owner = MiniUser.fromJson(j['owner'] as Map<String, dynamic>),
        steps = (j['steps'] as List).map((s) => QuestStep.fromJson(s as Map<String, dynamic>)).toList();

  final String id;
  final String title;
  final String? goal;
  final Category category;
  final QuestStatus status;
  final int rewardXp;
  final bool isParty;
  final DateTime? dueAt;
  final MiniUser owner;
  final List<QuestStep> steps;

  int get doneCount => steps.where((s) => s.done).length;
  double get fraction => steps.isEmpty ? 0 : doneCount / steps.length;

  /// Index of the first open step, or -1 when all are done.
  int get nextIndex => steps.indexWhere((s) => !s.done);
}

class Party {
  Party.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        inviteCode = j['inviteCode'] as String,
        members = (j['members'] as List).map((m) => Player.fromJson(m as Map<String, dynamic>)).toList();

  final String id;
  final String name;
  final String inviteCode;
  final List<Player> members;
}

class FeedEvent {
  FeedEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        type = j['type'] as String,
        message = j['message'] as String,
        xp = j['xp'] as int,
        createdAt = DateTime.parse(j['createdAt'] as String).toLocal(),
        user = MiniUser.fromJson(j['user'] as Map<String, dynamic>);

  final String id;
  final String type;
  final String message;
  final int xp;
  final DateTime createdAt;
  final MiniUser user;

  IconData get icon => switch (type) {
        'LEVEL_UP' => Icons.keyboard_double_arrow_up_rounded,
        'QUEST_COMPLETED' => Icons.emoji_events_rounded,
        'QUEST_STARTED' => Icons.flag_rounded,
        'QUEST_STEP_DONE' => Icons.check_circle_rounded,
        'PARTY_JOINED' => Icons.group_add_rounded,
        _ => Icons.bolt_rounded,
      };

  Color get color => switch (type) {
        'LEVEL_UP' || 'QUEST_COMPLETED' => Desert.orange,
        'QUEST_STEP_DONE' => Desert.teal,
        _ => Desert.inkSoft,
      };
}

/// What the server reports after logging an activity.
class LogResult {
  LogResult.fromJson(Map<String, dynamic> j)
      : activity = Activity.fromJson(j['activity'] as Map<String, dynamic>),
        xpGained = j['xpGained'] as int,
        streak = j['streak'] as int,
        levelUp = j['levelUp'] as int?,
        questTitle = (j['quest'] as Map<String, dynamic>?)?['questTitle'] as String?,
        stepTitle = (j['quest'] as Map<String, dynamic>?)?['stepTitle'] as String?,
        questCompleted = (j['quest'] as Map<String, dynamic>?)?['questCompleted'] as bool? ?? false,
        questReward = (j['quest'] as Map<String, dynamic>?)?['rewardXp'] as int? ?? 0;

  final Activity activity;
  final int xpGained;
  final int streak;
  final int? levelUp;
  final String? questTitle;
  final String? stepTitle;
  final bool questCompleted;
  final int questReward;
}

class QuestPreview {
  QuestPreview.fromJson(Map<String, dynamic> j)
      : rewardXp = j['rewardXp'] as int,
        durationDays = j['durationDays'] as int,
        stepCount = (j['steps'] as List).length;

  final int rewardXp;
  final int durationDays;
  final int stepCount;
}
