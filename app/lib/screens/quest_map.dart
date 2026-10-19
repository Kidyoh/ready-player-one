import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';

/// Quest steps laid out as a winding sand road on a parchment map, three stones per row,
/// snaking back and forth like the "1 week" journey screen in the mockup. The player's avatar
/// stands on the next open step, and desert props line the road.
class QuestMap extends StatefulWidget {
  const QuestMap({super.key, required this.quest, required this.onStepTap, this.avatarKey = 'sun'});

  final Quest quest;
  final ValueChanged<QuestStep> onStepTap;
  final String avatarKey;

  @override
  State<QuestMap> createState() => _QuestMapState();
}

class _QuestMapState extends State<QuestMap> with SingleTickerProviderStateMixin {
  static const _perRow = 3;
  static const _rowHeight = 104.0;
  // Room for the Boss HP header plus the avatar pin standing on a first-row stone.
  static const _topPad = 150.0;

  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  List<Offset> _positions(double width) {
    final xs = [width * 0.2, width * 0.5, width * 0.8];
    return [
      for (var i = 0; i < widget.quest.steps.length; i++)
        Offset(
          xs[(i ~/ _perRow).isEven ? i % _perRow : _perRow - 1 - i % _perRow],
          _topPad + (i ~/ _perRow) * _rowHeight,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E2A6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Desert.outline, width: 3),
        boxShadow: const [BoxShadow(color: Desert.outline, offset: Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final positions = _positions(width);
            final height = (positions.isEmpty ? 0.0 : positions.last.dy) + 100;
            final next = quest.nextIndex;
            final active = quest.status == QuestStatus.active;
            return SingleChildScrollView(
              child: SizedBox(
                height: math.max(height, constraints.maxHeight),
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _ParchmentPainter(positions, quest.id.hashCode, _topPad, _rowHeight))),
                    Positioned.fill(child: CustomPaint(painter: _RoadPainter(positions, next))),
                    Positioned(left: 14, top: 14, right: 14, child: _MapHeader(quest: quest)),
                    for (var i = 0; i < positions.length; i++)
                      Positioned(
                        left: positions[i].dx - (quest.steps[i].isBoss ? 34 : 27),
                        top: positions[i].dy - (quest.steps[i].isBoss ? 34 : 27),
                        child: _StepStone(
                          step: quest.steps[i],
                          index: i,
                          isNext: i == next && active,
                          onTap: () => widget.onStepTap(quest.steps[i]),
                        ),
                      ),
                    if (active && next >= 0)
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (_, child) => Positioned(
                          left: positions[next].dx - 20,
                          top: positions[next].dy - 74 - pulse.value * 6,
                          child: child!,
                        ),
                        child: IgnorePointer(child: _AvatarPin(avatarKey: widget.avatarKey)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.quest});
  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final done = quest.status == QuestStatus.completed;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Desert.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Desert.outline, width: 2.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(done ? 'Boss defeated!' : 'Boss HP', style: display(16, color: const Color(0xFF8C4A3A))),
              const Spacer(),
              Text('${quest.doneCount}/${quest.steps.length} · ${quest.rewardXp} XP', style: display(15)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 1 - quest.fraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: Desert.creamDeep,
                color: const Color(0xFFD9534A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPin extends StatelessWidget {
  const _AvatarPin({required this.avatarKey});
  final String avatarKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
          ),
          child: AvatarFace(avatarKey, size: 36),
        ),
        CustomPaint(size: const Size(14, 8), painter: _PinTip()),
      ],
    );
  }
}

class _PinTip extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sand texture plus props (cacti, palms, rocks, bones) placed in the gaps beside the road.
class _ParchmentPainter extends CustomPainter {
  _ParchmentPainter(this.points, this.seed, this.top, this.rowHeight);
  final List<Offset> points;
  final int seed;
  final double top;
  final double rowHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final speck = Paint()..color = Desert.dune.withValues(alpha: 0.18);
    for (var i = 0; i < 140; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), rnd.nextDouble() * 2 + 0.6, speck);
    }
    // Props sit between rows, offset from the road's x positions so they never cover a stone.
    final rows = points.isEmpty ? 0 : ((points.length - 1) ~/ 3) + 1;
    for (var row = 0; row < rows; row++) {
      // Props stand on the ground just above the next row, clear of both roads.
      final y = top + row * rowHeight + rowHeight * 0.68;
      for (final x in [size.width * 0.35, size.width * 0.65]) {
        if (rnd.nextDouble() < 0.55) _prop(canvas, Offset(x + (rnd.nextDouble() - 0.5) * 30, y), rnd.nextInt(4));
      }
    }
  }

  void _prop(Canvas canvas, Offset at, int kind) {
    switch (kind) {
      case 0: // cactus
        final p = Paint()
          ..color = const Color(0xFF6BA35A)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(at, at.translate(0, -26), p);
        canvas.drawPath(Path()..moveTo(at.dx, at.dy - 12)..lineTo(at.dx - 8, at.dy - 12)..lineTo(at.dx - 8, at.dy - 20), p);
        canvas.drawPath(Path()..moveTo(at.dx, at.dy - 16)..lineTo(at.dx + 8, at.dy - 16)..lineTo(at.dx + 8, at.dy - 24), p);
      case 1: // rocks
        final p = Paint()..color = const Color(0xFFC9B48A);
        canvas.drawOval(Rect.fromCenter(center: at, width: 22, height: 12), p);
        canvas.drawOval(Rect.fromCenter(center: at.translate(12, 2), width: 12, height: 8), p);
      case 2: // palm
        final trunk = Paint()
          ..color = const Color(0xFF9A6A3A)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(at, at.translate(3, -24), trunk);
        final leaf = Paint()..color = const Color(0xFF5DA05C);
        for (final a in [-2.6, -1.8, -1.0, -0.3]) {
          canvas.save();
          canvas.translate(at.dx + 3, at.dy - 24);
          canvas.rotate(a);
          canvas.drawOval(const Rect.fromLTWH(0, -3.5, 18, 7), leaf);
          canvas.restore();
        }
      default: // bones
        final bone = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(at.translate(-9, -3), at.translate(9, 3), bone);
        canvas.drawLine(at.translate(-9, 3), at.translate(9, -3), bone);
    }
  }

  @override
  bool shouldRepaint(covariant _ParchmentPainter old) => old.points.length != points.length || old.seed != seed;
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.points, this.nextIndex);
  final List<Offset> points;
  final int nextIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    Path pathThrough(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1];
        final b = pts[i];
        if (a.dy == b.dy) {
          p.lineTo(b.dx, b.dy);
        } else {
          // Row change: bow outwards so the road curves round like a switchback.
          final bulge = a.dx > size.width / 2 ? 50.0 : -50.0;
          p.cubicTo(a.dx + bulge, a.dy, b.dx + bulge, b.dy, b.dx, b.dy);
        }
      }
      return p;
    }

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final all = pathThrough(points);
    canvas.drawPath(all.shift(const Offset(0, 4)), stroke(Desert.outline.withValues(alpha: 0.25), 34));
    canvas.drawPath(all, stroke(Desert.outline.withValues(alpha: 0.6), 34));
    canvas.drawPath(all, stroke(const Color(0xFFFFF8DA), 26));

    // Dashed centre line on the road still to travel.
    final dash = stroke(Desert.sandDeep.withValues(alpha: 0.6), 3);
    for (final metric in all.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 16) {
        canvas.drawPath(metric.extractPath(d, d + 7), dash);
      }
    }

    // Travelled part of the road in warm sand.
    final reached = nextIndex == -1 ? points.length : nextIndex + 1;
    if (reached >= 2) {
      canvas.drawPath(pathThrough(points.sublist(0, reached)), stroke(Desert.mustard, 14));
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.points != points || old.nextIndex != nextIndex;
}

class _StepStone extends StatelessWidget {
  const _StepStone({required this.step, required this.index, required this.isNext, required this.onTap});

  final QuestStep step;
  final int index;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = step.isBoss ? 68.0 : 54.0;
    final Color fill;
    final Widget content;
    if (step.done) {
      fill = Desert.orange;
      content = Icon(step.isBoss ? Icons.emoji_events_rounded : Icons.check_rounded, color: Colors.white, size: 30);
    } else if (step.isBoss) {
      fill = const Color(0xFF8C4A3A);
      content = const Icon(Icons.whatshot_rounded, color: Colors.white, size: 34);
    } else {
      fill = isNext ? Desert.cream : Desert.stone;
      content = Text('${index + 1}', style: display(20, color: isNext ? Desert.ink : Colors.white));
    }
    return Semantics(
      button: true,
      label: 'Step ${index + 1}: ${step.title}${step.done ? ', done' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [Color.lerp(fill, Colors.white, 0.25)!, fill]),
            border: Border.all(color: isNext ? Desert.orange : Desert.outline, width: isNext ? 4 : 3),
            boxShadow: [
              const BoxShadow(color: Desert.outline, offset: Offset(0, 4)),
              if (isNext) BoxShadow(color: Desert.orange.withValues(alpha: 0.55), blurRadius: 14, spreadRadius: 3),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}
