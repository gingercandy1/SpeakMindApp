import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Hand-drawn stamp and postcard icons (S1 thick-outline flat colour),
/// used on the stamp-book page instead of the generic Material mail icons.
class StampIcon extends StatelessWidget {
  const StampIcon({
    super.key,
    this.size = 36,
    this.color = const Color(0xFFE8A33D),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _StampPainter(color)),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ink = Paint()
      ..color = const Color(0xFF2B2118)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, s * 0.06)
      ..strokeJoin = StrokeJoin.round;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.08, s * 0.06, s * 0.84, s * 0.88),
      Radius.circular(s * 0.08),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRRect(rect, ink);
    // Perforation: dashed inner border.
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.18, s * 0.16, s * 0.64, s * 0.68),
      Radius.circular(s * 0.05),
    );
    final path = Path()..addRRect(inner);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final len = math.min(s * 0.08, metric.length - dist);
        dashed.addPath(metric.extractPath(dist, dist + len), Offset.zero);
        dist += s * 0.08 + s * 0.06;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = const Color(0xFF2B2118)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.04)
        ..strokeCap = StrokeCap.round,
    );
    // Star in the middle.
    final star = Path();
    final c = Offset(s / 2, s * 0.5);
    final outer = s * 0.2;
    final innerR = s * 0.085;
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : innerR;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * radius;
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StampPainter old) => old.color != color;
}

/// A little postcard: picture on the left (sun + mountain), lines on the
/// right.
class PostcardIcon extends StatelessWidget {
  const PostcardIcon({
    super.key,
    this.size = 28,
    this.color = const Color(0xFF1F7A6D),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PostcardPainter(color)),
    );
  }
}

class _PostcardPainter extends CustomPainter {
  _PostcardPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ink = Paint()
      ..color = const Color(0xFF2B2118)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, s * 0.06)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.06, s * 0.14, s * 0.88, s * 0.72),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white);
    canvas.drawRRect(rect, ink);
    // Picture: sun + mountain.
    canvas.drawCircle(
      Offset(s * 0.26, s * 0.36),
      s * 0.08,
      Paint()..color = const Color(0xFFE8A33D),
    );
    final mountain = Path()
      ..moveTo(s * 0.10, s * 0.72)
      ..lineTo(s * 0.28, s * 0.44)
      ..lineTo(s * 0.46, s * 0.72)
      ..close();
    canvas.drawPath(mountain, Paint()..color = color);
    // Lines on the right.
    final linePaint = Paint()
      ..color = const Color(0xFF2B2118)
      ..strokeWidth = math.max(1.5, s * 0.05)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = s * (0.34 + i * 0.16);
      canvas.drawLine(Offset(s * 0.54, y), Offset(s * 0.88, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_PostcardPainter old) => old.color != color;
}
