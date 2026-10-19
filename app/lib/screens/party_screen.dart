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
            Text(party.inviteCode, style: display(24, color: Desert.outline).copyWith(letterSpacing: 3)),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 18, color: Desert.inkSoft),
          ],
        ),
      ),
      const SectionLabel('Leaderboard'),
      for (final (i, m) in party.members.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CreamCard(
            color: m.id == state.me?.id ? Desert.creamDeep : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _RankMedal(rank: i + 1),
                const SizedBox(width: 10),
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
                    Text('Lv ${m.level}', style: display(20, color: Desert.orange)),
                    Text('${m.totalXp} XP', style: const TextStyle(fontSize: 12, color: Desert.inkSoft)),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SectionLabel('Party feed'),
      if (state.feed.isEmpty)
        const EmptyState(icon: Icons.forum_rounded, title: 'Quiet camp', body: 'Activity from your party shows up here.'),
      for (final (i, e) in state.feed.indexed)
        FadeSlideIn(
          key: ValueKey('f-${e.id}'),
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CreamCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarFace(e.user.avatar, size: 40),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: e.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: Icon(e.icon, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.message, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(_ago(e.createdAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Desert.inkSoft)),
                      ],
                    ),
                  ),
                  if (e.user.id != state.me?.id || e.cheers > 0)
                    _CheerButton(event: e, mine: e.user.id == state.me?.id),
                ],
              ),
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

class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.rank});
  final int rank;

  static const _medals = [Color(0xFFF2C230), Color(0xFFC9CFD6), Color(0xFFD9925A)];

  @override
  Widget build(BuildContext context) {
    final medal = rank <= 3 ? _medals[rank - 1] : null;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: medal ?? Colors.transparent,
        border: medal == null ? null : Border.all(color: Desert.outline.withValues(alpha: 0.5), width: 2),
      ),
      child: Text('$rank', style: display(16, color: medal == null ? Desert.inkSoft : Desert.outline)),
    );
  }
}

/// Strava-style kudos: tap to cheer a party-mate's moment. Your own events just show the count.
class _CheerButton extends StatefulWidget {
  const _CheerButton({required this.event, required this.mine});
  final FeedEvent event;
  final bool mine;

  @override
  State<_CheerButton> createState() => _CheerButtonState();
}

class _CheerButtonState extends State<_CheerButton> {
  int pops = 0;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final on = e.cheeredByMe;
    return Pressable(
      onTap: widget.mine
          ? null
          : () {
              setState(() => pops++);
              guard(context, () => context.read<AppState>().toggleCheer(e));
            },
      child: TweenAnimationBuilder<double>(
        key: ValueKey(pops),
        tween: Tween(begin: pops == 0 ? 1 : 1.35, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Desert.orange : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? const Color(0xFFD9800F) : Desert.creamDeep, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👏', style: TextStyle(fontSize: 14, color: on ? Colors.white : null)),
              if (e.cheers > 0) ...[
                const SizedBox(width: 4),
                Text('${e.cheers}', style: TextStyle(fontWeight: FontWeight.w900, color: on ? Colors.white : Desert.ink)),
              ],
            ],
          ),
        ),
      ),
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
        const ScreenTitle('Party', subtitle: 'Adventure is better together'),
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
