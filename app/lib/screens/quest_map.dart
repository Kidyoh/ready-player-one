import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Quest steps laid out as a winding sand road on a parchment map, three stones per row,
/// snaking back and forth like the "1 week" journey screen in the mockup.
class QuestMap extends StatelessWidget {
  const QuestMap({super.key, required this.quest, required this.onStepTap});

  final Quest quest;
  final ValueChanged<QuestStep> onStepTap;

  static const _perRow = 3;
  static const _rowHeight = 96.0;
  static const _topPad = 96.0;

  List<Offset> _positions(double width) {
    final xs = [width * 0.2, width * 0.5, width * 0.8];
    return [
      for (var i = 0; i < quest.steps.length; i++)
        Offset(
          xs[(i ~/ _perRow).isEven ? i % _perRow : _perRow - 1 - i % _perRow],
          _topPad + (i ~/ _perRow) * _rowHeight,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E2A6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Desert.dune, width: 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final positions = _positions(width);
            final height = (positions.isEmpty ? 0.0 : positions.last.dy) + 90;
            final next = quest.nextIndex;
            return SingleChildScrollView(
              child: SizedBox(
                height: height < constraints.maxHeight ? constraints.maxHeight : height,
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _RoadPainter(positions, next))),
                    Positioned(
                      left: 14,
                      top: 12,
                      child: _Ribbon(
                        text: quest.status == QuestStatus.completed
                            ? 'Cleared!'
                            : '${quest.doneCount}/${quest.steps.length} · ${quest.rewardXp} XP',
                      ),
                    ),
                    for (var i = 0; i < positions.length; i++)
                      Positioned(
                        left: positions[i].dx - 26,
                        top: positions[i].dy - 26,
                        child: _StepStone(
                          step: quest.steps[i],
                          index: i,
                          isNext: i == next && quest.status == QuestStatus.active,
                          onTap: () => onStepTap(quest.steps[i]),
                        ),
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
          final bulge = a.dx > size.width / 2 ? 46.0 : -46.0;
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
    canvas.drawPath(all, stroke(Desert.outline.withValues(alpha: 0.55), 34));
    canvas.drawPath(all, stroke(const Color(0xFFFFF8DA), 26));

    // Travelled part of the road in warm sand.
    final reached = nextIndex == -1 ? points.length : nextIndex + 1;
    if (reached >= 2) {
      canvas.drawPath(pathThrough(points.sublist(0, reached)), stroke(Desert.mustard, 12));
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
    final Color fill;
    final Widget content;
    if (step.done) {
      fill = Desert.orange;
      content = const Icon(Icons.check_rounded, color: Colors.white, size: 28);
    } else if (step.isBoss) {
      fill = const Color(0xFF8C4A3A);
      content = const Icon(Icons.whatshot_rounded, color: Colors.white, size: 28);
    } else {
      fill = isNext ? Desert.cream : Desert.stone;
      content = Text('${index + 1}',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isNext ? Desert.ink : Colors.white));
    }
    return Semantics(
      button: true,
      label: 'Step ${index + 1}: ${step.title}${step.done ? ', done' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: isNext ? Desert.orange : Desert.outline, width: isNext ? 4 : 3),
            boxShadow: [
              const BoxShadow(color: Color(0x55000000), offset: Offset(0, 3)),
              if (isNext) BoxShadow(color: Desert.orange.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Desert.cream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Desert.outline, width: 2.5),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: Desert.outline)),
    );
  }
}
