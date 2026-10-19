import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';
import '../widgets/desert.dart';
import 'quest_map.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  QuestStatus tab = QuestStatus.active;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final quests = state.quests.where((q) => q.status == tab).toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle('Quests', subtitle: 'Real goals, one step at a time'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PillTabs<QuestStatus>(
                options: QuestStatus.values,
                selected: tab,
                onSelected: (s) => setState(() => tab = s),
                label: (s) => switch (s) {
                  QuestStatus.active => 'Active',
                  QuestStatus.completed => 'Completed',
                  QuestStatus.abandoned => 'Abandoned',
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => guard(context, state.refreshAll),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    if (quests.isEmpty)
                      EmptyState(
                        icon: Icons.map_rounded,
                        title: tab == QuestStatus.active ? 'No active quests' : 'Nothing here yet',
                        body: 'Turn a real goal, like "Run a 5k" or "Finish a book", into a quest with +.',
                      ),
                    for (final (i, q) in quests.indexed)
                      FadeSlideIn(
                        key: ValueKey('q-${q.id}'),
                        index: i,
                        child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _QuestCard(quest: q)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: RoundAddButton(
            tooltip: 'New quest',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NewQuestScreen())),
          ),
        ),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});
  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    // Habitica-style: the quest is a boss whose HP is the steps still standing.
    final hp = 1 - q.fraction;
    final remaining = q.steps.length - q.doneCount;
    return CreamCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuestDetailScreen(questId: q.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(color: q.category.color, icon: q.category.icon, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.title, style: display(20)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (q.isParty) ...[
                          const Icon(Icons.groups_rounded, color: Desert.teal, size: 16),
                          const SizedBox(width: 4),
                          const Text('Party · ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Desert.teal)),
                        ],
                        Text(
                          q.dueAt != null && q.status == QuestStatus.active
                              ? 'Due ${DateFormat.MMMd().format(q.dueAt!)}'
                              : '${q.category.label} → ${q.category.stat}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Desert.inkSoft),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE2B8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Desert.orange, width: 1.5),
                ),
                child: Text('${q.rewardXp} XP', style: display(14, color: const Color(0xFFB86A00))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (q.status == QuestStatus.active) ...[
            Row(
              children: [
                const Icon(Icons.whatshot_rounded, size: 16, color: Color(0xFF8C4A3A)),
                const SizedBox(width: 4),
                const Text('BOSS HP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFF8C4A3A))),
                const Spacer(),
                Text('$remaining / ${q.steps.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 5),
            XpBar(fraction: hp, color: const Color(0xFFD9534A), height: 12),
          ] else
            Row(
              children: [
                Icon(q.status == QuestStatus.completed ? Icons.emoji_events_rounded : Icons.flag_outlined,
                    color: q.status == QuestStatus.completed ? Desert.orange : Desert.inkSoft),
                const SizedBox(width: 6),
                Text(q.status == QuestStatus.completed ? 'Boss defeated!' : 'Abandoned',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
        ],
      ),
    );
  }
}

class QuestDetailScreen extends StatelessWidget {
  const QuestDetailScreen({super.key, required this.questId});
  final String questId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final quest = state.questById(questId);
    return Scaffold(
      body: DesertBackground(
        scenery: false,
        child: SafeArea(
          child: quest == null
              ? const Center(child: Text('Quest not found', style: TextStyle(color: Colors.white)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const BackButton(color: Colors.white),
                        Expanded(
                          child: Text(
                            quest.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: display(24, color: Colors.white, weight: FontWeight.w600, shadows: titleShadow),
                          ),
                        ),
                        if (quest.status == QuestStatus.active && quest.owner.id == state.me?.id)
                          IconButton(
                            tooltip: 'Abandon quest',
                            icon: const Icon(Icons.flag_outlined, color: Colors.white),
                            onPressed: () => _abandon(context, quest),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          AvatarFace(quest.owner.avatar, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '${quest.isParty ? 'Party quest by' : 'Quest of'} ${quest.owner.displayName} · '
                            '${quest.category.label} → ${quest.category.stat}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: QuestMap(
                        quest: quest,
                        avatarKey: state.me?.avatar ?? 'sun',
                        onStepTap: (step) => _stepSheet(context, quest, step),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _abandon(BuildContext context, Quest quest) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Desert.cream,
        title: const Text('Abandon quest?'),
        content: const Text('Progress is kept in your history, but the reward is lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abandon')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await guard(context, () => context.read<AppState>().abandonQuest(quest));
    }
  }

  void _stepSheet(BuildContext context, Quest quest, QuestStep step) {
    final isNext = quest.nextIndex == quest.steps.indexOf(step);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Desert.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Step ${step.position + 1} of ${quest.steps.length}', style: const TextStyle(color: Desert.inkSoft)),
            const SizedBox(height: 4),
            Text(step.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 10),
            if (step.done)
              Text(
                'Cleared ${DateFormat.MMMd().format(step.completedAt!)}'
                '${step.completedBy != null ? ' by ${step.completedBy!.displayName}' : ''}',
                style: const TextStyle(color: Desert.teal, fontWeight: FontWeight.w700),
              )
            else if (step.isBoss)
              const Text('The final challenge. Mark it done once you have actually reached your goal.')
            else
              Text('Log ${step.targetMinutes}+ minutes of ${quest.category.practice} and this step clears itself.'),
            if (!step.done && quest.status == QuestStatus.active) ...[
              const SizedBox(height: 18),
              ChunkyButton(
                label: step.isBoss ? 'Defeat the boss' : 'Mark done',
                onPressed: isNext || step.isBoss
                    ? () async {
                        Navigator.pop(ctx);
                        await guard(context, () => context.read<AppState>().completeStep(quest, step));
                      }
                    : null,
              ),
              if (!isNext && !step.isBoss)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Clear the earlier steps first.', textAlign: TextAlign.center, style: TextStyle(color: Desert.inkSoft)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Builds a quest from a real-world goal and shows the plan before committing.
class NewQuestScreen extends StatefulWidget {
  const NewQuestScreen({super.key});

  @override
  State<NewQuestScreen> createState() => _NewQuestScreenState();
}

class _NewQuestScreenState extends State<NewQuestScreen> {
  final goal = TextEditingController();
  Category category = Category.workout;
  double weeks = 2;
  double sessions = 3;
  double minutes = 30;
  bool forParty = false;
  bool busy = false;
  QuestPreview? preview;

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  @override
  void dispose() {
    goal.dispose();
    super.dispose();
  }

  Future<void> _refreshPreview() async {
    try {
      final p = await context
          .read<AppState>()
          .api
          .previewQuest('preview', category, weeks.round(), sessions.round(), minutes.round());
      if (mounted) setState(() => preview = p);
    } catch (_) {
      // Preview is a nicety; the form still works without it.
    }
  }

  Future<void> create() async {
    if (goal.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('What is the goal?')));
      return;
    }
    setState(() => busy = true);
    Quest? quest;
    await guard(context, () async {
      quest = await context
          .read<AppState>()
          .createQuest(goal.text.trim(), category, weeks.round(), sessions.round(), minutes.round(), forParty);
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (quest != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => QuestDetailScreen(questId: quest!.id)));
    }
  }

  Widget _slider(String label, double value, double min, double max, String unit, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
            onChangeEnd: (_) => _refreshPreview(),
          ),
        ),
        SizedBox(width: 64, child: Text('${value.round()} $unit', style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inParty = context.watch<AppState>().party != null;
    return Scaffold(
      body: DesertBackground(
        scenery: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              const Row(
                children: [
                  BackButton(color: Colors.white),
                  Text('New quest', style: TextStyle(fontFamily: 'Fredoka', color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              CreamCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Your real goal', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    TextField(controller: goal, decoration: const InputDecoration(hintText: 'e.g. Run a 5k, Read Dune, Ship my app')),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in Category.values)
                          ChoiceChip(
                            avatar: Icon(c.icon, size: 16, color: category == c ? Colors.white : c.color),
                            label: Text(c.label),
                            selected: category == c,
                            showCheckmark: false,
                            selectedColor: c.color,
                            backgroundColor: Colors.white.withValues(alpha: 0.6),
                            labelStyle: TextStyle(fontWeight: FontWeight.w700, color: category == c ? Colors.white : Desert.ink),
                            onSelected: (_) {
                              setState(() => category = c);
                              _refreshPreview();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _slider('Weeks', weeks, 1, 12, 'wk', (v) => setState(() => weeks = v)),
                    _slider('Sessions/wk', sessions, 1, 7, 'x', (v) => setState(() => sessions = v)),
                    _slider('Per session', minutes, 5, 120, 'min', (v) => setState(() => minutes = v)),
                    if (inParty)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Desert.orange,
                        title: const Text('Party quest', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Anyone in your party can clear steps; everyone gets the reward.'),
                        value: forParty,
                        onChanged: (v) => setState(() => forParty = v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (preview != null)
                CreamCard(
                  color: Desert.creamDeep,
                  child: Row(
                    children: [
                      const Icon(Icons.map_rounded, color: Desert.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${preview!.stepCount} steps over ${preview!.durationDays} days, ending in a boss fight.\n'
                          'Reward: ${preview!.rewardXp} XP',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              ChunkyButton(label: 'Accept quest', busy: busy, onPressed: create),
            ],
          ),
        ),
      ),
    );
  }
}
