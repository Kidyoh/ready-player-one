import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/desert.dart';
import 'integrations_screen.dart';

/// Character sheet: the hero in their world, today's goal and streak, the week, and the stat shape.
class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me!;

    return RefreshIndicator(
      onRefresh: () => guard(context, () async {
        await state.refreshAll();
        await state.syncAll();
      }),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.displayName, style: display(28, color: Colors.white, weight: FontWeight.w600, shadows: titleShadow)),
                      Text(me.title.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit hero',
                onPressed: () => _editProfile(context, me),
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ],
          ),
          HeroDiorama(
            avatar: AvatarFace(me.avatar, size: 112),
            level: me.level,
            fraction: me.progress.fraction,
          ),
          FadeSlideIn(
            child: Center(
              child: Text(
                '${me.progress.xpForNextLevel - me.progress.xpIntoLevel} XP to level ${me.level + 1}',
                style: const TextStyle(color: Desert.ink, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            index: 1,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _DailyGoalCard(xp: me.todayXp)),
                  const SizedBox(width: 12),
                  Expanded(child: _StreakCard(streak: me.currentStreak, week: me.week)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 2,
            child: CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('This week', style: display(19)),
                      const Spacer(),
                      CountUp(
                        me.week.fold(0, (s, d) => s + d.xp),
                        suffix: ' XP',
                        style: display(19, color: Desert.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  WeekBars(week: me.week),
                ],
              ),
            ),
          ),
          const SectionLabel('Stats'),
          FadeSlideIn(
            index: 3,
            child: CreamCard(
              child: Row(
                children: [
                  StatRadar(stats: me.stats, size: 150),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        for (final stat in me.stats)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(stat.category.icon, size: 16, color: stat.category.color),
                                    const SizedBox(width: 5),
                                    Text(stat.category.stat, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    const Spacer(),
                                    Text('Lv ${stat.progress.level}', style: display(15, color: stat.category.color)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                XpBar(fraction: stat.progress.fraction, color: stat.category.color, height: 8),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionLabel('Auto-sync'),
          FadeSlideIn(index: 4, child: _SyncCard(state: state)),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context, Character me) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Desert.cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditProfileSheet(me: me),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) {
    final done = xp >= dailyXpGoal;
    return CreamCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ProgressRing(
            fraction: xp / dailyXpGoal,
            size: 92,
            stroke: 11,
            color: done ? Desert.teal : Desert.orange,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CountUp(xp, style: display(24)),
                Text('/ $dailyXpGoal', style: const TextStyle(fontSize: 11, color: Desert.inkSoft, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(done ? 'Goal smashed!' : 'Daily XP', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// Duolingo-style streak: a big flame and a dot for each of the last seven days.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.week});
  final int streak;
  final List<DayXp> week;

  @override
  Widget build(BuildContext context) {
    final lit = streak > 0;
    return CreamCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 46, color: lit ? Desert.orange : Desert.stone),
              CountUp(streak, style: display(38, color: lit ? Desert.orange : Desert.stone)),
            ],
          ),
          Text(lit ? 'day streak' : 'Start a streak', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in week)
                Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d.xp > 0 ? Desert.orange : Desert.creamDeep,
                        border: Border.all(color: d.xp > 0 ? const Color(0xFFD9800F) : Desert.sandDeep, width: 1.5),
                      ),
                      child: d.xp > 0 ? const Icon(Icons.check_rounded, size: 11, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 2),
                    Text(DateFormat.E().format(d.day).substring(0, 1),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Desert.inkSoft)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String label, Color color, bool on) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: on ? color : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? color : Desert.creamDeep, width: 2),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: on ? Colors.white : color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: on ? Colors.white : Desert.ink)),
                ),
                Icon(on ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                    size: 16, color: on ? Colors.white : Desert.inkSoft),
              ],
            ),
          ),
        );
    return CreamCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const IntegrationsScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.github.connected || state.healthStatus.connected
                      ? 'Your real activity earns XP on its own.'
                      : 'Connect GitHub and ${state.health.storeName} so commits and workouts earn XP on their own.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (state.syncing)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Desert.orange))
              else
                const Icon(Icons.chevron_right_rounded, color: Desert.inkSoft),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              chip(Icons.code_rounded, state.github.login ?? 'GitHub', Desert.github, state.github.connected),
              const SizedBox(width: 8),
              chip(Icons.favorite_rounded, state.health.storeName, Desert.health, state.healthStatus.connected),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.me});
  final Character me;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final name = TextEditingController(text: widget.me.displayName);
  late String avatar = widget.me.avatar;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit hero', style: display(24)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            children: [
              for (final s in AvatarStyle.values)
                GestureDetector(
                  onTap: () => setState(() => avatar = s.name),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: avatar == s.name ? Desert.orange : Colors.transparent, width: 3),
                    ),
                    child: AvatarFace(s.name, size: 40),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(hintText: 'Hero name')),
          const SizedBox(height: 16),
          ChunkyButton(
            label: 'Save',
            busy: busy,
            onPressed: () async {
              setState(() => busy = true);
              final ok = await guard(context, () => state.updateProfile(displayName: name.text, avatar: avatar));
              if (!context.mounted) return;
              setState(() => busy = false);
              if (ok) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
          Text(widget.me.email, textAlign: TextAlign.center, style: const TextStyle(color: Desert.inkSoft, fontSize: 12)),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              state.signOut();
            },
            child: const Text('Sign out', style: TextStyle(color: Color(0xFFB4442E), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
