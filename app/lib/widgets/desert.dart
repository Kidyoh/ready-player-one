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

/// Finch/Habitica-style header: the player's avatar standing on the dunes, gently bobbing,
/// wrapped in a ring that fills with level progress. A sun slowly turns behind them.
class HeroDiorama extends StatefulWidget {
  const HeroDiorama({super.key, required this.avatar, required this.level, required this.fraction, this.height = 270});

  final Widget avatar;
  final int level;
  final double fraction;
  final double height;

  @override
  State<HeroDiorama> createState() => _HeroDioramaState();
}

class _HeroDioramaState extends State<HeroDiorama> with SingleTickerProviderStateMixin {
  late final AnimationController loop = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) {
          final t = loop.value;
          final bob = math.sin(t * math.pi * 4) * 4;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(top: 4, child: _Sun(rotation: t * math.pi * 2 / 6)),
              // The dunes fade out at the bottom so the header melts into the page instead of ending in a hard edge.
              Positioned(
                left: -16,
                right: -16,
                bottom: 0,
                height: 120,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.6, 1],
                  ).createShader(rect),
                  child: const CustomPaint(painter: _HeaderDunes()),
                ),
              ),
              // Shadow under the avatar shrinks as it bobs up.
              Positioned(
                bottom: 30,
                child: Container(
                  width: 96 - bob * 2,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Desert.outline.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              Positioned(
                bottom: 40 - bob,
                child: _LevelRing(level: widget.level, fraction: widget.fraction, child: widget.avatar),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Sun extends StatelessWidget {
  const _Sun({required this.rotation});
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: CustomPaint(size: const Size.square(200), painter: _SunPainter()),
    );
  }
}

class _SunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rays = Paint()..color = Colors.white.withValues(alpha: 0.13);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.12) * 100, c.dy + math.sin(a - 0.12) * 100)
        ..lineTo(c.dx + math.cos(a + 0.12) * 100, c.dy + math.sin(a + 0.12) * 100)
        ..close();
      canvas.drawPath(path, rays);
    }
    canvas.drawCircle(c, 62, Paint()..color = const Color(0x33FFF4BE));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderDunes extends CustomPainter {
  const _HeaderDunes();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    void dune(double top, double amp, double phase, Color color) {
      final path = Path()..moveTo(0, h * top);
      for (var x = 0.0; x <= w; x += 6) {
        path.lineTo(x, h * top + math.sin(x / w * math.pi * 1.6 + phase) * amp);
      }
      path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    dune(0.35, 12, 0.2, const Color(0x55EBD98E));
    dune(0.55, 10, 2.4, const Color(0xCCE6CB7A));
    dune(0.72, 8, 4.4, Desert.sandDeep);
    DunesPainter()._cactus(canvas, Offset(w * 0.1, h * 0.78), 0.8);
    DunesPainter()._palm(canvas, Offset(w * 0.86, h * 0.7), 0.85);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LevelRing extends StatelessWidget {
  const _LevelRing({required this.level, required this.fraction, required this.child});

  final int level;
  final double fraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 164,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(size: const Size.square(150), painter: _RingArc(v)),
          ),
          Positioned(top: 19, child: child),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Desert.orange,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 3), blurRadius: 4)],
              ),
              child: Text('LV $level', style: display(20, color: Colors.white, weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingArc extends CustomPainter {
  _RingArc(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(7);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint..color = Desert.mustard);
  }

  @override
  bool shouldRepaint(covariant _RingArc old) => old.value != value;
}
