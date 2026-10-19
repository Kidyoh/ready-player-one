import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';

/// "My diary" list, reworked as an adventure log of real activities.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  Category? filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.activities.where((a) => filter == null || a.category == filter).toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle('Adventure log', subtitle: '${state.activities.length} entries · ${state.me?.totalXp ?? 0} XP earned'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PillTabs<Category?>(
                options: const [null, ...Category.values],
                selected: filter,
                onSelected: (c) => setState(() => filter = c),
                label: (c) => c?.label ?? 'All',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => guard(context, state.refreshAll),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    if (items.isEmpty)
                      const EmptyState(
                        icon: Icons.auto_stories_rounded,
                        title: 'No entries yet',
                        body: 'Log a workout, a reading session or some coding to earn your first XP.',
                      ),
                    for (final (i, group) in _byDay(items).indexed) ...[
                      _DayHeader(day: group.$1, entries: group.$2),
                      for (final (j, a) in group.$2.indexed)
                        FadeSlideIn(
                          key: ValueKey('in-${a.id}'),
                          index: i * 3 + j,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: a.source != ActivitySource.manual
                                ? _ActivityTile(activity: a)
                                : Dismissible(
                                    key: ValueKey(a.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 22),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB4442E),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                                    ),
                                    confirmDismiss: (_) => _confirmDelete(context, a),
                                    onDismissed: (_) => guard(context, () => state.deleteActivity(a)),
                                    child: _ActivityTile(activity: a),
                                  ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: RoundAddButton(tooltip: 'Log activity', onPressed: () => showLogSheet(context)),
        ),
      ],
    );
  }

  /// Groups activities (already newest first) by local calendar day.
  List<(DateTime, List<Activity>)> _byDay(List<Activity> items) {
    final groups = <(DateTime, List<Activity>)>[];
    for (final a in items) {
      final day = DateTime(a.createdAt.year, a.createdAt.month, a.createdAt.day);
      if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
      groups.last.$2.add(a);
    }
    return groups;
  }

  Future<bool> _confirmDelete(BuildContext context, Activity a) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Desert.cream,
            title: const Text('Delete entry?'),
            content: Text('"${a.title}" and its ${a.xp} XP will be removed.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.entries});
  final DateTime day;
  final List<Activity> entries;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat.MMMEd().format(day);
    final xp = entries.fold(0, (s, a) => s + a.xp);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Text(label, style: display(19, color: Colors.white, weight: FontWeight.w600, shadows: titleShadow)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
            child: Text('+$xp XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return CreamCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          CategoryBadge(color: a.category.color, icon: a.category.icon, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${DateFormat.jm().format(a.createdAt)} · ${a.minutes} min',
                      style: const TextStyle(color: Desert.inkSoft, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    if (a.source != ActivitySource.manual) ...[const SizedBox(width: 6), SourceBadge(a.source)],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${a.xp}', style: display(22, color: a.category.color)),
              Text(a.category.stat.toUpperCase(),
                  style: const TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900, color: Desert.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paper-sheet editor like the mockup's "Enter the topic" note, with Cancel / Save.
Future<void> showLogSheet(BuildContext context) async {
  final result = await showModalBottomSheet<LogResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LogSheet(),
  );
  if (result != null && context.mounted) {
    await showDialog<void>(context: context, builder: (_) => RewardDialog(result: result));
  }
}

class _LogSheet extends StatefulWidget {
  const _LogSheet();

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  final title = TextEditingController();
  final note = TextEditingController();
  Category category = Category.workout;
  double minutes = 30;
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give it a name first')));
      return;
    }
    setState(() => busy = true);
    LogResult? result;
    await guard(context, () async {
      result = await context.read<AppState>().logActivity(category, title.text.trim(), minutes.round(), note.text.trim());
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (result != null) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Desert.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Desert.creamDeep, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Desert.creamDeep,
                  child: Icon(Icons.edit_note_rounded, color: Desert.orange),
                ),
                const SizedBox(width: 10),
                Text(DateFormat.yMMMd().format(DateTime.now()), style: const TextStyle(color: Desert.inkSoft)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              autofocus: true,
              style: display(22),
              decoration: const InputDecoration(hintText: 'What did you do?'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in Category.values)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 16, color: category == c ? Colors.white : c.color),
                    label: Text('${c.label} → ${c.stat}'),
                    selected: category == c,
                    showCheckmark: false,
                    selectedColor: c.color,
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: category == c ? Colors.white : Desert.ink,
                    ),
                    onSelected: (_) => setState(() => category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: Desert.inkSoft, size: 20),
                Expanded(
                  child: Slider(
                    value: minutes,
                    min: 5,
                    max: 180,
                    divisions: 35,
                    label: '${minutes.round()} min',
                    onChanged: (v) => setState(() => minutes = v),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text('${minutes.round()} min', style: display(17)),
                ),
              ],
            ),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'How did it go? (optional)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: ChunkyButton(label: 'Cancel', filled: false, onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 12),
                Expanded(child: ChunkyButton(label: 'Save', busy: busy, onPressed: save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RewardDialog extends StatefulWidget {
  const RewardDialog({super.key, required this.result});
  final LogResult result;

  @override
  State<RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<RewardDialog> {
  @override
  void initState() {
    super.initState();
    if (widget.result.levelUp != null || widget.result.questCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => celebrate(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final cat = result.activity.category;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Dialog(
        backgroundColor: Desert.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Desert.outline, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.levelUp != null) ...[
                Text('LEVEL UP!', style: display(34, color: Desert.orange)),
                Text('You reached level ${result.levelUp}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
              ],
              CategoryBadge(color: cat.color, icon: cat.icon, size: 72),
              const SizedBox(height: 12),
              CountUp(result.xpGained, prefix: '+', suffix: ' XP', style: display(44)),
              Text('${cat.stat} grows stronger', style: const TextStyle(color: Desert.inkSoft, fontWeight: FontWeight.w700)),
              if (result.streak > 1) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFE2B8), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Desert.orange, size: 18),
                      const SizedBox(width: 4),
                      Text('${result.streak} day streak bonus', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
              if (result.questTitle != null) ...[
                const SizedBox(height: 14),
                CreamCard(
                  color: Desert.creamDeep,
                  child: Row(
                    children: [
                      Icon(result.questCompleted ? Icons.emoji_events_rounded : Icons.flag_rounded, color: Desert.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.questCompleted
                              ? 'Quest complete: ${result.questTitle}! +${result.questReward} XP'
                              : 'Quest progress: ${result.stepTitle}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ChunkyButton(label: 'Onward', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}
