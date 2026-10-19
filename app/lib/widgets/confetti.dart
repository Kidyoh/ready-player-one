import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Fires a one-shot burst of confetti over the whole screen. Used for level-ups and quest clears.
void celebrate(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.heavyImpact();
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => IgnorePointer(child: _ConfettiBurst(onDone: () => entry.remove())));
  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Piece {
  _Piece(math.Random r)
      : x = 0.5 + (r.nextDouble() - 0.5) * 0.3,
        vx = (r.nextDouble() - 0.5) * 1.6,
        vy = -(1.1 + r.nextDouble() * 0.9),
        spin = (r.nextDouble() - 0.5) * 18,
        size = 6 + r.nextDouble() * 7,
        color = _colors[r.nextInt(_colors.length)],
        round = r.nextBool();

  static const _colors = [Desert.orange, Desert.mustard, Desert.teal, Color(0xFFE5604A), Color(0xFF5A7FD1), Colors.white];

  final double x, vx, vy, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiBurstState extends State<_ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..forward().whenComplete(widget.onDone);
  final pieces = List.generate(90, (i) => _Piece(math.Random(i * 7919)));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => CustomPaint(size: MediaQuery.sizeOf(context), painter: _ConfettiPainter(pieces, controller.value)),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final time = t * 2.4;
    const gravity = 1.6;
    final fade = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    for (final p in pieces) {
      final dx = (p.x + p.vx * time * 0.35) * size.width;
      final dy = size.height * 0.62 + (p.vy * time + 0.5 * gravity * time * time) * size.height * 0.45;
      final paint = Paint()..color = p.color.withValues(alpha: fade.clamp(0, 1));
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * time);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), const Radius.circular(2)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
