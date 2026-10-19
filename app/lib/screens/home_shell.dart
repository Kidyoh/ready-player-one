import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/desert.dart';
import 'character_screen.dart';
import 'log_screen.dart';
import 'party_screen.dart';
import 'quests_screen.dart';

/// Hosts the four tabs above the dark wooden bottom bar from the mockup.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;
  late final AppState state = context.read<AppState>();

  static const _tabs = [
    (Icons.person_rounded, 'Hero'),
    (Icons.auto_stories_rounded, 'Log'),
    (Icons.map_rounded, 'Quests'),
    (Icons.groups_rounded, 'Party'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.notices.addListener(_showNotice);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.notices.removeListener(_showNotice);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Coming back from a run or a coding session is exactly when new XP is waiting.
    if (lifecycle == AppLifecycleState.resumed) state.syncAll();
  }

  void _showNotice() {
    final message = state.notices.value;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    state.notices.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesertBackground(
        scenery: false,
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: index,
            children: const [CharacterScreen(), LogScreen(), QuestsScreen(), PartyScreen()],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Desert.bark,
          border: Border(top: BorderSide(color: Desert.dune, width: 4)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _TabButton(
                    icon: _tabs[i].$1,
                    label: _tabs[i].$2,
                    selected: i == index,
                    onTap: () {
                      if (i != index) HapticFeedback.selectionClick();
                      setState(() => index = i);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? Desert.mustard : Desert.creamDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: Desert.outline, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: selected ? const Color(0xFF2E2016) : Colors.transparent, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Icon(icon, color: Desert.outline, size: 24),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: display(13, color: selected ? Desert.mustard : Desert.creamDeep, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
