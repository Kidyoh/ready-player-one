import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import '../widgets/desert.dart';

/// Connect real-world sources so activities earn XP without manual logging.
class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: DesertBackground(
        scenery: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              const Align(alignment: Alignment.centerLeft, child: BackButton(color: Colors.white)),
              const ScreenTitle('Auto-sync', subtitle: 'Your real life, counted for you.'),
              FadeSlideIn(child: _GitHubCard(state: state)),
              const SizedBox(height: 14),
              FadeSlideIn(index: 1, child: _HealthCard(state: state)),
              const SectionLabel('How synced XP works'),
              FadeSlideIn(
                index: 2,
                child: CreamCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _Rule(Icons.code_rounded, 'Each GitHub contribution (commit, PR, review, issue) counts as ~10 min of coding, up to 2 h a day → Craft.'),
                      _Rule(Icons.fitness_center, 'Workouts count by their real duration → Strength.'),
                      _Rule(Icons.self_improvement, 'Mindful minutes from Apple Health → Spirit.'),
                      _Rule(Icons.history_rounded, 'Connecting imports the last 7 days. Nothing is ever counted twice.'),
                      _Rule(Icons.flag_rounded, 'Synced activity advances your quests just like a manual log.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Desert.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// Shared shell for an integration: coloured banner on top, cream body below.
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.color,
    required this.icon,
    required this.name,
    required this.status,
    required this.child,
  });

  final Color color;
  final IconData icon;
  final String name;
  final IntegrationStatus status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Desert.outline, width: 3),
        boxShadow: const [BoxShadow(color: Desert.outline, offset: Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: display(22, color: Colors.white, weight: FontWeight.w600)),
                      Text(
                        status.connected
                            ? 'Connected${status.login != null ? ' · ${status.login}' : ''}'
                            : 'Not connected',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (status.connected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Desert.teal, borderRadius: BorderRadius.circular(20)),
                    child: const Text('ON', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
          ),
          Container(color: Desert.cream, padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

String _lastSynced(IntegrationStatus s) =>
    s.lastSyncedAt == null ? 'Never synced' : 'Last synced ${DateFormat.MMMd().add_jm().format(s.lastSyncedAt!)}';

class _ConnectedControls extends StatefulWidget {
  const _ConnectedControls({required this.status, required this.onSync, required this.onDisconnect});

  final IntegrationStatus status;
  final Future<SyncSummary?> Function() onSync;
  final Future<void> Function() onDisconnect;

  @override
  State<_ConnectedControls> createState() => _ConnectedControlsState();
}

class _ConnectedControlsState extends State<_ConnectedControls> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_lastSynced(widget.status), style: const TextStyle(color: Desert.inkSoft, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ChunkyButton(
          label: 'Sync now',
          icon: Icons.sync_rounded,
          busy: busy,
          onPressed: () async {
            setState(() => busy = true);
            SyncSummary? result;
            await guard(context, () async => result = await widget.onSync());
            if (!context.mounted) return;
            setState(() => busy = false);
            if (result != null) await showSyncResult(context, result!);
          },
        ),
        TextButton(
          onPressed: () => guard(context, widget.onDisconnect),
          child: const Text('Disconnect', style: TextStyle(color: Color(0xFFB4442E), fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _GitHubCard extends StatelessWidget {
  const _GitHubCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return _ProviderCard(
      color: Desert.github,
      icon: Icons.code_rounded,
      name: 'GitHub',
      status: state.github,
      child: state.github.connected
          ? _ConnectedControls(
              status: state.github,
              onSync: () async {
                final s = await state.api.syncGitHub();
                await state.refreshAll();
                return s;
              },
              onDisconnect: state.disconnectGitHub,
            )
          : state.github.deviceFlow
              ? const _GitHubDeviceConnect()
              : const _GitHubTokenConnect(),
    );
  }
}

/// "Sign in with GitHub" via the OAuth device flow: show a code, open github.com, wait.
class _GitHubDeviceConnect extends StatefulWidget {
  const _GitHubDeviceConnect();

  @override
  State<_GitHubDeviceConnect> createState() => _GitHubDeviceConnectState();
}

class _GitHubDeviceConnectState extends State<_GitHubDeviceConnect> {
  DeviceFlow? flow;
  bool cancelled = false;
  bool starting = false;

  @override
  void dispose() {
    cancelled = true;
    super.dispose();
  }

  Future<void> start() async {
    final state = context.read<AppState>();
    setState(() {
      starting = true;
      cancelled = false;
    });
    await guard(context, () async {
      final f = await state.api.startGitHubDeviceFlow();
      if (!mounted) return;
      setState(() => flow = f);
      await Clipboard.setData(ClipboardData(text: f.userCode));
      await launchUrl(Uri.parse(f.verificationUri), mode: LaunchMode.externalApplication);
      final result = await state.finishGitHubDeviceFlow(f, () => cancelled);
      if (result != null && mounted) await showSyncResult(context, result);
    });
    if (mounted) {
      setState(() {
        starting = false;
        flow = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = flow;
    if (f == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Commits, pull requests and reviews turn into Craft XP every day.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ChunkyButton(label: 'Sign in with GitHub', color: Desert.github, busy: starting, onPressed: start),
        ],
      );
    }
    return Column(
      children: [
        const Text('Enter this code on GitHub', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SelectableText(f.userCode, style: display(36, color: Desert.github).copyWith(letterSpacing: 4)),
        const Text('(copied to your clipboard)', style: TextStyle(color: Desert.inkSoft, fontSize: 12)),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5, color: Desert.orange)),
            SizedBox(width: 8),
            Text('Waiting for you to approve…', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => launchUrl(Uri.parse(f.verificationUri), mode: LaunchMode.externalApplication),
              child: const Text('Open GitHub again'),
            ),
            TextButton(onPressed: () => setState(() => cancelled = true), child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}

/// Fallback when the server has no OAuth app: paste a personal access token.
class _GitHubTokenConnect extends StatefulWidget {
  const _GitHubTokenConnect();

  @override
  State<_GitHubTokenConnect> createState() => _GitHubTokenConnectState();
}

class _GitHubTokenConnectState extends State<_GitHubTokenConnect> {
  final token = TextEditingController();
  bool busy = false;

  static final _newTokenUrl = Uri.parse('https://github.com/settings/tokens/new?scopes=read:user&description=Life%20RPG');

  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create a token with only the read:user scope, then paste it here. '
          'It is stored encrypted and only used to read your contribution count.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        TextButton.icon(
          onPressed: () => launchUrl(_newTokenUrl, mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Create a token on GitHub'),
        ),
        TextField(
          controller: token,
          obscureText: true,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'ghp_…'),
        ),
        const SizedBox(height: 12),
        ChunkyButton(
          label: 'Connect',
          color: Desert.github,
          busy: busy,
          onPressed: () async {
            setState(() => busy = true);
            SyncSummary? result;
            await guard(context, () async => result = await context.read<AppState>().connectGitHubToken(token.text.trim()));
            if (!context.mounted) return;
            setState(() => busy = false);
            if (result != null) await showSyncResult(context, result!);
          },
        ),
      ],
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final name = state.health.storeName;
    Widget body;
    if (!state.health.supported) {
      body = Text('$name sync works in the Android and iOS apps.', style: const TextStyle(fontWeight: FontWeight.w700));
    } else if (state.healthStatus.connected) {
      body = _ConnectedControls(
        status: state.healthStatus,
        onSync: () async {
          final s = await state.connectHealth();
          return s;
        },
        onDisconnect: state.disconnectHealth,
      );
    } else {
      body = _HealthConnect(name: name);
    }
    return _ProviderCard(color: Desert.health, icon: Icons.favorite_rounded, name: name, status: state.healthStatus, child: body);
  }
}

class _HealthConnect extends StatefulWidget {
  const _HealthConnect({required this.name});
  final String name;

  @override
  State<_HealthConnect> createState() => _HealthConnectState();
}

class _HealthConnectState extends State<_HealthConnect> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Runs, rides, lifts and yoga from ${widget.name} turn into Strength XP automatically.',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ChunkyButton(
          label: 'Connect ${widget.name}',
          color: Desert.health,
          busy: busy,
          onPressed: () async {
            setState(() => busy = true);
            SyncSummary? result;
            var declined = false;
            await guard(context, () async {
              result = await context.read<AppState>().connectHealth();
              declined = result == null;
            });
            if (!context.mounted) return;
            setState(() => busy = false);
            if (declined) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.name} access was not granted. Install or open ${widget.name} and try again.')),
              );
            } else if (result != null) {
              await showSyncResult(context, result!);
            }
          },
        ),
      ],
    );
  }
}

Future<void> showSyncResult(BuildContext context, SyncSummary s) async {
  if (s.xpGained > 0) celebrate(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Desert.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Desert.outline, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.changed ? Icons.auto_awesome_rounded : Icons.check_circle_rounded, size: 48, color: Desert.orange),
            const SizedBox(height: 8),
            if (s.changed) ...[
              CountUp(s.xpGained, prefix: '+', suffix: ' XP', style: display(40)),
              const SizedBox(height: 4),
              Text(
                '${s.imported} new · ${s.updated} updated',
                style: const TextStyle(color: Desert.inkSoft, fontWeight: FontWeight.w700),
              ),
            ] else
              Text('All caught up', style: display(26)),
            if (s.levelUp != null) ...[
              const SizedBox(height: 8),
              Text('LEVEL ${s.levelUp}!', style: display(26, color: Desert.orange)),
            ],
            for (final q in s.questsAdvanced.toSet())
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('🚩 Progress on $q', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 18),
            ChunkyButton(label: 'Nice', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    ),
  );
}
