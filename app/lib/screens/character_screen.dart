import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';

/// Character sheet. The big level readout takes the place of the mockup's clock.
class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.me!;
    final activeQuests = state.quests.where((q) => q.status == QuestStatus.active).length;

    return RefreshIndicator(
      onRefresh: () => guard(context, state.refreshAll),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Edit hero',
                onPressed: () => _editProfile(context, me),
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ],
          ),
          Center(child: AvatarFace(me.avatar, size: 84)),
          const SizedBox(height: 6),
          Text(
            'LV ${me.level}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 64,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: Color(0x553B2A1A), offset: Offset(0, 3))],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${me.displayName} · ${me.title}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Experience', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${me.progress.xpIntoLevel} / ${me.progress.xpForNextLevel} XP',
                        style: const TextStyle(color: Desert.inkSoft, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                XpBar(fraction: me.progress.fraction, height: 14),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Chip(icon: Icons.local_fire_department_rounded, text: '${me.currentStreak} day streak'),
                    const SizedBox(width: 8),
                    _Chip(icon: Icons.flag_rounded, text: '$activeQuests active quests'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Stats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          for (final stat in me.stats)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CreamCard(
                child: Row(
                  children: [
                    CategoryBadge(color: stat.category.color, icon: stat.category.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(stat.category.stat, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(width: 6),
                              Text('from ${stat.category.practice}',
                                  style: const TextStyle(color: Desert.inkSoft, fontSize: 12)),
                              const Spacer(),
                              Text('Lv ${stat.progress.level}',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Desert.orange)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          XpBar(fraction: stat.progress.fraction, color: stat.category.color),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context, Character me) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Desert.cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditProfileSheet(me: me),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Desert.creamDeep, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Desert.orange),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
          const Text('Edit hero', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
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
