import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Teal-to-sand sky with layered dunes, a pyramid and a few cacti along the bottom.
class DesertBackground extends StatelessWidget {
  const DesertBackground({super.key, required this.child, this.scenery = true});

  final Widget child;
  final bool scenery;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Desert.skyGradient),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _StarsPainter())),
          if (scenery)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 260,
              child: CustomPaint(painter: DunesPainter()),
            ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 26; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.35);
      canvas.drawCircle(o, rnd.nextDouble() * 1.4 + 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DunesPainter extends CustomPainter {
  const DunesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Pyramid on the horizon, with a shaded side like the mockup.
    final apex = Offset(w * 0.68, h * 0.18);
    final baseL = Offset(w * 0.48, h * 0.62);
    final baseR = Offset(w * 0.9, h * 0.62);
    final baseMid = Offset(w * 0.74, h * 0.62);
    canvas.drawPath(
      Path()..addPolygon([apex, baseL, baseMid], true),
      Paint()..color = const Color(0xFFE9C277),
    );
    canvas.drawPath(
      Path()..addPolygon([apex, baseMid, baseR], true),
      Paint()..color = const Color(0xFFC08A43),
    );

    void dune(double top, double amp, double phase, Color color) {
      final path = Path()..moveTo(0, h * top);
      for (var x = 0.0; x <= w; x += 8) {
        path.lineTo(x, h * top + math.sin(x / w * math.pi * 2 + phase) * amp);
      }
      path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    dune(0.55, 10, 0.5, const Color(0xFFE6CB7A));
    dune(0.68, 14, 2.1, Desert.sandDeep);
    dune(0.82, 10, 4.0, Desert.dune);

    _cactus(canvas, Offset(w * 0.14, h * 0.7), 1.0);
    _cactus(canvas, Offset(w * 0.9, h * 0.8), 0.8);
    _palm(canvas, Offset(w * 0.3, h * 0.66), 0.9);
  }

  void _cactus(Canvas canvas, Offset base, double s) {
    final paint = Paint()
      ..color = const Color(0xFF5E9B4C)
      ..strokeWidth = 9 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(base, base.translate(0, -42 * s), paint);
    final arm = Path()
      ..moveTo(base.dx, base.dy - 18 * s)
      ..lineTo(base.dx - 12 * s, base.dy - 18 * s)
      ..lineTo(base.dx - 12 * s, base.dy - 30 * s);
    canvas.drawPath(arm, paint);
    final arm2 = Path()
      ..moveTo(base.dx, base.dy - 26 * s)
      ..lineTo(base.dx + 11 * s, base.dy - 26 * s)
      ..lineTo(base.dx + 11 * s, base.dy - 36 * s);
    canvas.drawPath(arm2, paint);
  }

  void _palm(Canvas canvas, Offset base, double s) {
    final trunk = Paint()
      ..color = const Color(0xFF8A5A2E)
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final top = base.translate(6 * s, -56 * s);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx - 4 * s, base.dy - 30 * s, top.dx, top.dy),
      trunk,
    );
    final leaf = Paint()..color = const Color(0xFF4E9A52);
    for (final angle in [-2.6, -1.9, -1.2, -0.5, 0.2]) {
      canvas.save();
      canvas.translate(top.dx, top.dy);
      canvas.rotate(angle);
      canvas.drawOval(Rect.fromLTWH(0, -5 * s, 30 * s, 10 * s), leaf);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
