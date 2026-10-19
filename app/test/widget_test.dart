import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_rpg/models.dart';
import 'package:life_rpg/screens/quest_map.dart';

Map<String, dynamic> _step(int i, {bool done = false, int target = 30}) => {
      'id': 's$i',
      'position': i,
      'title': target == 0 ? 'Boss: Run a 5k' : 'Week 1 · $target min of training',
      'targetMinutes': target,
      'completedAt': done ? '2026-10-19T10:00:00.000Z' : null,
      'completedBy': done ? {'id': 'u1', 'displayName': 'Hero', 'avatar': 'sun'} : null,
    };

Quest _quest() => Quest.fromJson({
      'id': 'q1',
      'title': 'Run a 5k',
      'goal': 'Run a 5k',
      'category': 'WORKOUT',
      'status': 'ACTIVE',
      'rewardXp': 190,
      'partyId': null,
      'dueAt': '2026-11-02T10:00:00.000Z',
      'owner': {'id': 'u1', 'displayName': 'Hero', 'avatar': 'sun'},
      'steps': [_step(0, done: true), _step(1, done: true), _step(2), _step(3), _step(4, target: 0)],
    });

void main() {
  test('parses quests and finds the next open step', () {
    final q = _quest();
    expect(q.category, Category.workout);
    expect(q.doneCount, 2);
    expect(q.nextIndex, 2);
    expect(q.steps.last.isBoss, isTrue);
    expect(q.steps.first.completedBy?.displayName, 'Hero');
  });

  test('parses a character sheet', () {
    final c = Character.fromJson({
      'id': 'u1',
      'displayName': 'Hero',
      'avatar': 'dusk',
      'level': 3,
      'title': 'Apprentice',
      'totalXp': 350,
      'currentStreak': 2,
      'email': 'h@x.dev',
      'longestStreak': 4,
      'progress': {'level': 3, 'xp': 350, 'xpIntoLevel': 50, 'xpForNextLevel': 300},
      'stats': [
        {'category': 'READING', 'name': 'Intellect', 'level': 2, 'xp': 120, 'xpIntoLevel': 20, 'xpForNextLevel': 200},
      ],
    });
    expect(c.progress.fraction, closeTo(1 / 6, 1e-9));
    expect(c.stats.single.category.stat, 'Intellect');
  });

  testWidgets('quest map draws one stone per step and reports taps', (tester) async {
    QuestStep? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: QuestMap(quest: _quest(), onStepTap: (s) => tapped = s)),
    ));

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.whatshot_rounded), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2/5 · 190 XP'), findsOneWidget);

    await tester.tap(find.text('3'));
    expect(tapped?.id, 's2');
  });
}
