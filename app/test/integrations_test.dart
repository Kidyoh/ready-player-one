import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_rpg/integrations/health_service.dart';
import 'package:life_rpg/models.dart';
import 'package:life_rpg/widgets/charts.dart';

void main() {
  test('health sessions serialize to UTC for the API', () {
    final s = HealthSession(
      id: 'hc-1',
      kind: 'WORKOUT',
      title: 'Running',
      start: DateTime.utc(2026, 10, 19, 7),
      end: DateTime.utc(2026, 10, 19, 7, 40),
    );
    expect(s.toJson(), {
      'id': 'hc-1',
      'kind': 'WORKOUT',
      'title': 'Running',
      'start': '2026-10-19T07:00:00.000Z',
      'end': '2026-10-19T07:40:00.000Z',
    });
  });

  test('health is unsupported off-phone', () {
    // Tests run on the desktop VM, which has no health store.
    expect(HealthService().supported, isFalse);
  });

  test('parses sync summaries, integration status and activity sources', () {
    final s = SyncSummary.fromJson({'imported': 2, 'updated': 1, 'xpGained': 140, 'levelUp': null, 'questsAdvanced': ['Ship v1']});
    expect(s.changed, isTrue);
    expect(s.questsAdvanced.single, 'Ship v1');

    final gh = IntegrationStatus.fromJson({'connected': true, 'login': 'octo', 'lastSyncedAt': null, 'deviceFlow': true});
    expect(gh.connected && gh.deviceFlow, isTrue);

    final a = Activity.fromJson({
      'id': 'a', 'category': 'CODING', 'title': '4 GitHub contributions', 'minutes': 40, 'note': null,
      'xp': 80, 'source': 'GITHUB', 'createdAt': '2026-10-19T12:00:00.000Z',
    });
    expect(a.source, ActivitySource.github);
  });

  testWidgets('week bars and stat radar render', (tester) async {
    final week = [for (var i = 0; i < 7; i++) DayXp(DateTime(2026, 10, 13 + i), i * 20)];
    final stats = [
      for (final c in Category.values)
        Stat.fromJson({'category': c.api, 'level': 2, 'xp': 150, 'xpIntoLevel': 50, 'xpForNextLevel': 200}),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(children: [WeekBars(week: week), StatRadar(stats: stats)])),
    ));
    await tester.pumpAndSettle();
    expect(find.text('120'), findsOneWidget); // today's bar label
    expect(find.byType(StatRadar), findsOneWidget);
  });
}
