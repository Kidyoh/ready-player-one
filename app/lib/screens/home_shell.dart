import 'package:flutter/material.dart';

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

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  static const _tabs = [
    (Icons.person_rounded, 'Hero'),
    (Icons.auto_stories_rounded, 'Log'),
    (Icons.map_rounded, 'Quests'),
    (Icons.groups_rounded, 'Party'),
  ];

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
                    onTap: () => setState(() => index = i),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? Desert.mustard : Desert.creamDeep,
                shape: BoxShape.circle,
                border: Border.all(color: Desert.outline, width: 2.5),
              ),
              child: Icon(icon, color: Desert.outline, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Desert.mustard : Desert.creamDeep,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
