import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme.dart';

/// Apple-Fitness-style ring that sweeps to [fraction] on first build.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    required this.size,
    required this.color,
    this.stroke = 10,
    this.track,
    this.child,
  });

  final double fraction;
  final double size;
  final double stroke;
  final Color color;
  final Color? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0, 1)),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(v, color, track ?? color.withValues(alpha: 0.18), stroke),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track, this.stroke);
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (value <= 0) return;
    // A full 2π arc can vanish on some renderers, so a complete ring stops a hair short.
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * math.min(value, 0.9999), false, paint..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value || old.color != color;
}

/// Seven-day XP bars; today is highlighted and labelled.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.week, this.height = 110});

  final List<DayXp> week;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxXp = week.fold<int>(0, (m, d) => math.max(m, d.xp));
    final scale = maxXp == 0 ? 1.0 : maxXp.toDouble();
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, d) in week.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (d.xp > 0)
                      Text('${d.xp}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: i == week.length - 1 ? Desert.orange : Desert.inkSoft,
                          )),
                    const SizedBox(height: 2),
                    // The bar fills whatever height the labels leave, so text metrics can't overflow it.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, box) => Align(
                          alignment: Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: d.xp / scale),
                            duration: Duration(milliseconds: 700 + i * 70),
                            curve: Curves.easeOutBack,
                            builder: (_, v, _) => Container(
                              height: math.max(6, box.maxHeight * v.clamp(0, 1)),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: i == week.length - 1
                                      ? const [Color(0xFFFFC15A), Desert.orange]
                                      : d.xp > 0
                                          ? const [Color(0xFFF0D77F), Desert.sandDeep]
                                          : [Desert.creamDeep, Desert.creamDeep],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat.E().format(d.day).substring(0, 1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: i == week.length - 1 ? Desert.ink : Desert.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Diamond radar of the four stats, the classic RPG character-sheet shape.
class StatRadar extends StatelessWidget {
  const StatRadar({super.key, required this.stats, this.size = 170});

  final List<Stat> stats;
  final double size;

  @override
  Widget build(BuildContext context) {
    final maxLevel = stats.fold<int>(1, (m, s) => math.max(m, s.progress.level));
    // Scale to the strongest stat (with headroom) so a young character still has a visible shape.
    final ceiling = math.max(5, maxLevel + 1).toDouble();
    final values = [
      for (final s in stats) ((s.progress.level - 1) + s.progress.fraction + 0.6) / ceiling,
    ];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutBack,
      builder: (_, t, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _RadarPainter(values.map((v) => v * t).toList(), stats)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.values, this.stats);
  final List<double> values;
  final List<Stat> stats;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 18;
    final n = values.length;
    Offset point(int i, double scale) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return c + Offset(math.cos(a), math.sin(a)) * r * scale;
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = Desert.outline.withValues(alpha: 0.15)
      ..strokeWidth = 1.5;
    for (final ring in [0.33, 0.66, 1.0]) {
      canvas.drawPath(Path()..addPolygon([for (var i = 0; i < n; i++) point(i, ring)], true), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, point(i, 1), grid);
    }

    final shape = Path()..addPolygon([for (var i = 0; i < n; i++) point(i, values[i].clamp(0.05, 1.05))], true);
    canvas.drawPath(shape, Paint()..color = Desert.orange.withValues(alpha: 0.35));
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = Desert.orange,
    );
    for (var i = 0; i < n; i++) {
      final p = point(i, values[i].clamp(0.05, 1.05));
      canvas.drawCircle(p, 6, Paint()..color = stats[i].category.color);
      canvas.drawCircle(
        p,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.values != values;
}
