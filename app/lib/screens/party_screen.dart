import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/common.dart';

class PartyScreen extends StatelessWidget {
  const PartyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final party = state.party;
    return RefreshIndicator(
      onRefresh: () => guard(context, state.refreshAll),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: party == null ? const [_NoParty()] : _partyView(context, state, party),
      ),
    );
  }

  List<Widget> _partyView(BuildContext context, AppState state, Party party) {
    return [
      ScreenTitle(
        party.name,
        trailing: IconButton(
          tooltip: 'Leave party',
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () => _leave(context, state),
        ),
      ),
      CreamCard(
        onTap: () {
          Clipboard.setData(ClipboardData(text: party.inviteCode));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied')));
        },
        child: Row(
          children: [
            const Icon(Icons.vpn_key_rounded, color: Desert.orange),
            const SizedBox(width: 10),
            const Expanded(child: Text('Invite code', style: TextStyle(fontWeight: FontWeight.w700))),
            Text(party.inviteCode,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 3, color: Desert.outline)),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 18, color: Desert.inkSoft),
          ],
        ),
      ),
      const _SectionLabel('Leaderboard'),
      for (final (i, m) in party.members.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CreamCard(
            color: m.id == state.me?.id ? Desert.creamDeep : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: Desert.inkSoft)),
                ),
                AvatarFace(m.avatar, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(m.displayName,
                                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          if (m.isLeader)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.star_rounded, size: 16, color: Desert.orange),
                            ),
                        ],
                      ),
                      Text('${m.title} · 🔥 ${m.currentStreak}',
                          style: const TextStyle(fontSize: 12, color: Desert.inkSoft)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Lv ${m.level}', style: const TextStyle(fontWeight: FontWeight.w900, color: Desert.orange)),
                    Text('${m.totalXp} XP', style: const TextStyle(fontSize: 12, color: Desert.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
        ),
      const _SectionLabel('Party feed'),
      if (state.feed.isEmpty)
        const EmptyState(icon: Icons.forum_rounded, title: 'Quiet camp', body: 'Activity from your party shows up here.'),
      for (final e in state.feed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: CreamCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                AvatarFace(e.user.avatar, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(_ago(e.createdAt), style: const TextStyle(fontSize: 11, color: Desert.inkSoft)),
                    ],
                  ),
                ),
                Icon(e.icon, color: e.color),
              ],
            ),
          ),
        ),
    ];
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return DateFormat.MMMd().format(t);
  }

  Future<void> _leave(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Desert.cream,
        title: const Text('Leave party?'),
        content: const Text('You can rejoin later with the invite code.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true && context.mounted) await guard(context, state.leaveParty);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
    );
  }
}

class _NoParty extends StatefulWidget {
  const _NoParty();

  @override
  State<_NoParty> createState() => _NoPartyState();
}

class _NoPartyState extends State<_NoParty> {
  final name = TextEditingController();
  final code = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    await guard(context, action);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenTitle('Party'),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Text(
            'Adventure is better together. Form a party with friends to share quests, '
            'split the rewards and cheer each other on.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        CreamCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Form a party', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(controller: name, decoration: const InputDecoration(hintText: 'Party name')),
              const SizedBox(height: 12),
              ChunkyButton(
                label: 'Create',
                busy: busy,
                onPressed: () => run(() => state.createParty(name.text.trim())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CreamCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Join with a code', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: const InputDecoration(hintText: 'ABC123', counterText: ''),
              ),
              const SizedBox(height: 12),
              ChunkyButton(
                label: 'Join',
                filled: false,
                busy: busy,
                onPressed: () => run(() => state.joinParty(code.text.trim())),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
