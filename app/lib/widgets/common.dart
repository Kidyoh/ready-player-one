import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';

/// Squishes slightly while pressed and gives a light haptic tick, so every tap feels physical.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => down = true) : null,
      onTapCancel: enabled ? () => setState(() => down = false) : null,
      onTapUp: enabled ? (_) => setState(() => down = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: down ? widget.scale : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Parchment card with a thicker "ledge" along the bottom edge, giving it a little depth.
class CreamCard extends StatelessWidget {
  const CreamCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.color});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? Desert.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Desert.creamDeep, width: 2),
        boxShadow: const [BoxShadow(color: Desert.creamDeep, offset: Offset(0, 4))],
      ),
      padding: padding,
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.98, child: card);
  }
}

/// Duolingo-style 3D button: the face sinks onto its ledge while pressed.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.filled = true,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool filled;
  final IconData? icon;
  final Color? color;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool down = false;
  static const ledge = 5.0;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final face = widget.color ?? (widget.filled ? Desert.mustard : Desert.cream);
    final onFace = widget.color != null ? Colors.white : Desert.outline;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => down = true) : null,
          onTapCancel: () => setState(() => down = false),
          onTapUp: (_) => setState(() => down = false),
          onTap: enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  widget.onPressed!();
                }
              : null,
          child: SizedBox(
            height: 54 + ledge,
            child: Stack(
              children: [
                Positioned.fill(
                  top: ledge,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Desert.outline, borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 70),
                  left: 0,
                  right: 0,
                  top: down ? ledge : 0,
                  height: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      color: face,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Desert.outline, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: widget.busy
                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: onFace))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.icon != null) ...[Icon(widget.icon, color: onFace, size: 20), const SizedBox(width: 8)],
                              Text(
                                widget.label.toUpperCase(),
                                style: display(17, color: onFace, weight: FontWeight.w600).copyWith(letterSpacing: 1.5),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
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
              child: Pressable(
                onTap: () => onSelected(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: o == selected ? Desert.cream : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: o == selected ? Desert.mustard : Colors.white.withValues(alpha: 0.25), width: 2),
                  ),
                  child: Text(
                    label(o),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: o == selected ? Desert.ink : Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Progress bar that animates to its value, with a glossy highlight like a game HUD.
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
        border: Border.all(color: Desert.outline.withValues(alpha: 0.18)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                stops: const [0, 0.5],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Integer that counts up from its previous value, used for XP and levels.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style, this.prefix = '', this.suffix = '', this.from = 0});

  final int value;
  final int from;
  final TextStyle style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from.toDouble(), end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('$prefix${v.round()}$suffix', style: style),
    );
  }
}

/// Fades and slides a child up into place; pass increasing [index] values to stagger a list.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 10)) * 0.06;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + (delay * 1000).round()),
      curve: Interval(delay / (0.42 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// Large white headline with a brown drop, used for screen titles.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.trailing, this.subtitle});

  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: display(32, color: Colors.white, weight: FontWeight.w600, shadows: titleShadow)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Round cream "+" button from the mockup's lower-right corner, with a 3D ledge.
class RoundAddButton extends StatelessWidget {
  const RoundAddButton({super.key, required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Pressable(
        onTap: onPressed,
        scale: 0.9,
        child: Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            color: Desert.mustard,
            shape: BoxShape.circle,
            border: Border.fromBorderSide(BorderSide(color: Desert.outline, width: 3)),
            boxShadow: [BoxShadow(color: Desert.outline, offset: Offset(0, 4)), BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 8))],
          ),
          child: const Icon(Icons.add_rounded, size: 36, color: Desert.outline),
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
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.3)!, color],
        ),
        border: Border.all(color: Desert.outline.withValues(alpha: 0.45), width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }
}

/// Tiny corner badge showing where a synced activity came from.
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key});
  final ActivitySource source;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (source) {
      ActivitySource.github => (Icons.commit_rounded, Desert.github, 'GitHub'),
      ActivitySource.health => (Icons.favorite_rounded, Desert.health, 'Health'),
      ActivitySource.manual => (Icons.edit_rounded, Desert.inkSoft, 'Manual'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
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
          Icon(icon, size: 46, color: Desert.orange),
          const SizedBox(height: 8),
          Text(title, style: display(20)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Desert.inkSoft, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Section header in white on the sky.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: display(21, color: Colors.white, weight: FontWeight.w600, shadows: titleShadow))),
          ?trailing,
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
