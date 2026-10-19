import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';

/// Parchment card with a soft deeper-cream border, the main surface in the design.
class CreamCard extends StatelessWidget {
  const CreamCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.color});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Desert.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Desert.creamDeep, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// The chunky outlined "SIGN IN" style button.
class ChunkyButton extends StatelessWidget {
  const ChunkyButton({super.key, required this.label, required this.onPressed, this.busy = false, this.filled = true});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: filled ? Desert.mustard : Desert.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Desert.outline, width: 3),
            boxShadow: const [BoxShadow(color: Desert.outline, offset: Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Desert.outline))
              : Text(
                  label.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Desert.outline, fontSize: 16),
                ),
        ),
      ),
    );
  }
}

/// Row of rounded tabs like the month / clock selectors in the mockup.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({super.key, required this.options, required this.selected, required this.onSelected, required this.label});

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onSelected(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: o == selected ? Desert.cream : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: o == selected ? Desert.mustard : Colors.transparent, width: 2),
                  ),
                  child: Text(
                    label(o),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: o == selected ? Desert.ink : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.fraction, this.color = Desert.orange, this.height = 10});

  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Desert.creamDeep,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: Desert.outline.withValues(alpha: 0.25)),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
        ),
      ),
    );
  }
}

/// Large white headline with a brown drop, used for screen titles.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(color: Color(0x553B2A1A), offset: Offset(0, 2))],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Round cream "+" button from the mockup's lower-right corner.
class RoundAddButton extends StatelessWidget {
  const RoundAddButton({super.key, required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Desert.cream,
        shape: const CircleBorder(side: BorderSide(color: Desert.outline, width: 2.5)),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(width: 58, height: 58, child: Icon(Icons.add, size: 32, color: Desert.outline)),
        ),
      ),
    );
  }
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.color, required this.icon, this.size = 40});

  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Desert.outline.withValues(alpha: 0.5), width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return CreamCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Desert.orange),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Desert.inkSoft)),
        ],
      ),
    );
  }
}

/// Runs an async action and shows its error as a snackbar instead of throwing.
Future<bool> guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}
