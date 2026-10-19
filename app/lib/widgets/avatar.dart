import 'package:flutter/material.dart';

import '../theme.dart';

/// The round mood faces from the mockup, reused as player avatars.
enum AvatarStyle {
  sun(Color(0xFFF39A1F), AvatarMood.grin),
  cactus(Color(0xFF6BAF5B), AvatarMood.calm),
  oasis(Color(0xFF3FB3A3), AvatarMood.smile),
  dune(Color(0xFFE6BF35), AvatarMood.smile),
  dusk(Color(0xFF5A7FD1), AvatarMood.calm),
  ember(Color(0xFFE5604A), AvatarMood.grin);

  const AvatarStyle(this.color, this.mood);
  final Color color;
  final AvatarMood mood;

  static AvatarStyle of(String key) => values.firstWhere((v) => v.name == key, orElse: () => sun);
}

enum AvatarMood { grin, smile, calm }

class AvatarFace extends StatelessWidget {
  const AvatarFace(this.avatarKey, {super.key, this.size = 44});

  final String avatarKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FacePainter(AvatarStyle.of(avatarKey))),
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.style);
  final AvatarStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = style.color);
    canvas.drawCircle(
      c,
      r - 1.5,
      Paint()
        ..color = Desert.outline.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Cheeks
    final cheek = Paint()..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawCircle(c.translate(-r * 0.5, r * 0.18), r * 0.13, cheek);
    canvas.drawCircle(c.translate(r * 0.5, r * 0.18), r * 0.13, cheek);

    final ink = Paint()
      ..color = Desert.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.11;

    // Eyes: happy arcs for grin, dots otherwise.
    for (final dx in [-r * 0.32, r * 0.32]) {
      final eye = c.translate(dx, -r * 0.12);
      if (style.mood == AvatarMood.grin) {
        canvas.drawArc(Rect.fromCenter(center: eye, width: r * 0.3, height: r * 0.26), 3.4, 2.6, false, ink);
      } else if (style.mood == AvatarMood.calm) {
        canvas.drawLine(eye.translate(-r * 0.12, 0), eye.translate(r * 0.12, 0), ink);
      } else {
        canvas.drawCircle(eye, r * 0.08, Paint()..color = Desert.ink);
      }
    }

    final mouthRect = Rect.fromCenter(center: c.translate(0, r * 0.22), width: r * 0.62, height: r * 0.46);
    if (style.mood == AvatarMood.grin) {
      canvas.drawArc(mouthRect, 0.1, 2.94, true, Paint()..color = const Color(0xFF7A2E1E));
    } else {
      canvas.drawArc(mouthRect.deflate(r * 0.06), 0.3, 2.54, false, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) => oldDelegate.style != style;
}
