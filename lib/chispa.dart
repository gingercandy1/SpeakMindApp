/// Chispa the little fire dragon (吉祥物).
///
/// Final planning doc p.9: clean version — green body, orange horns, small
/// red scarf, heart-shaped flame; plain light-green belly, only a row of
/// small triangular dorsal fins on the back, no diamond scales anywhere.
///
/// The name is the doc's single undecided item (recommended Chispa,
/// alternatives Chispa / Drago). Until the user picks one, every user-facing
/// reference uses [mascotName] below — rename it in this one place and the
/// whole app follows.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The mascot's display name. Single source of truth — see above.
const String mascotName = 'Chispa';

/// Chispa's expressions (final planning doc p.9: 6; `discover` is the extra
/// one the levels dev doc §7 adds for hidden-level discoveries).
enum ChispaMood {
  /// Waving hello (map marker, intro card).
  greeting,

  /// Three stars / big win: happy closed eyes, open mouth, heart flame.
  cheer,

  /// Working something out (0 stars, thinking).
  thinking,

  /// Keep going (1-2 stars, hints, encouragement).
  encourage,

  /// Three days away / late night: closed eyes, little smoke rings.
  sleepy,

  /// Two stars / nailed it: half-lidded eyes, smirk.
  proud,

  /// A hidden level was just found: wide eyes, sparkle.
  discover,
}

/// Which face to show on the results screen for a star count.
ChispaMood moodForStars(int stars) => switch (stars) {
      3 => ChispaMood.cheer,
      2 => ChispaMood.proud,
      1 => ChispaMood.encourage,
      _ => ChispaMood.thinking,
    };

/// Chispa's face and body, drawn as a vector (S1 thick-outline flat
/// colour): deep-green round head, two small orange horns, big oval eyes,
/// small smile, red scarf at the neck, green body with a plain light-green
/// belly, small orange wings and a row of triangular dorsal fins. No
/// bitmap assets.
class ChispaFace extends StatelessWidget {
  const ChispaFace({super.key, required this.mood, this.size = 72});

  final ChispaMood mood;

  /// Face diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ChispaPainter(mood)),
    );
  }
}

class _ChispaPainter extends CustomPainter {
  _ChispaPainter(this.mood);

  final ChispaMood mood;

  static const _green = Color(0xFF43A047);
  static const _bellyGreen = Color(0xFFA5D6A7);
  static const _hornOrange = Color(0xFFF28C28);
  static const _scarfRed = Color(0xFFC7502B);
  static const _ink = Color(0xFF2B2118);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    // Head is the top third; the body fills the rest.
    final r = s * 0.27;
    final headCenter = Offset(cx, s * 0.30);
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, r * 0.08)
      ..strokeCap = StrokeCap.round;

    // Wings first (behind the body).
    _wing(canvas, cx, s, -1);
    _wing(canvas, cx, s, 1);

    // Body: green rounded shape with a plain light-green belly.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, s * 0.74),
        width: s * 0.52,
        height: s * 0.42,
      ),
      const Radius.circular(0.5),
    );
    canvas.drawRRect(bodyRect, Paint()..color = _green);
    canvas.drawRRect(bodyRect, line);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, s * 0.78),
        width: s * 0.32,
        height: s * 0.26,
      ),
      Paint()..color = _bellyGreen,
    );

    // Dorsal fins: three small triangles along the body's top edge,
    // peeking out from behind the head.
    final fin = Paint()..color = _hornOrange;
    for (final dir in [-1.0, 1.0]) {
      final base = Offset(cx + dir * r * 0.95, s * 0.56);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy - r * 0.34)
          ..lineTo(base.dx + dir * r * 0.22, base.dy)
          ..lineTo(base.dx - dir * r * 0.22, base.dy)
          ..close(),
        fin,
      );
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy - r * 0.34)
          ..lineTo(base.dx + dir * r * 0.22, base.dy)
          ..lineTo(base.dx - dir * r * 0.22, base.dy)
          ..close(),
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, r * 0.05),
      );
    }

    // Horns: two small orange triangles on top of the head.
    final horn = Paint()..color = _hornOrange;
    for (final dir in [-1.0, 1.0]) {
      final tip = Offset(cx + dir * r * 0.52, headCenter.dy - r * 1.28);
      final baseA = Offset(cx + dir * r * 0.78, headCenter.dy - r * 0.72);
      final baseB = Offset(cx + dir * r * 0.28, headCenter.dy - r * 0.82);
      canvas.drawPath(
        Path()..moveTo(tip.dx, tip.dy)..lineTo(baseA.dx, baseA.dy)
          ..lineTo(baseB.dx, baseB.dy)..close(),
        horn,
      );
      canvas.drawPath(
        Path()..moveTo(tip.dx, tip.dy)..lineTo(baseA.dx, baseA.dy)
          ..lineTo(baseB.dx, baseB.dy)..close(),
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, r * 0.05)
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Head: green circle with a thick dark outline (S1 style).
    canvas.drawCircle(headCenter, r, Paint()..color = _green);
    canvas.drawCircle(headCenter, r, line);

    // Scarf: red band across the neck, with a small fluttering end.
    final scarfBand = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, s * 0.545),
        width: r * 1.7,
        height: r * 0.34,
      ),
      Radius.circular(r * 0.17),
    );
    canvas.drawRRect(scarfBand, Paint()..color = _scarfRed);
    canvas.drawRRect(scarfBand, line);
    final scarfEnd = Path()
      ..moveTo(cx + r * 0.72, s * 0.545)
      ..lineTo(cx + r * 1.15, s * 0.50)
      ..lineTo(cx + r * 1.05, s * 0.62)
      ..lineTo(cx + r * 0.78, s * 0.60)
      ..close();
    canvas.drawPath(scarfEnd, Paint()..color = _scarfRed);
    canvas.drawPath(scarfEnd, line);

    final eyeY = headCenter.dy - r * 0.12;
    final eyeDx = r * 0.38;
    final white = Paint()..color = Colors.white;
    final black = Paint()..color = _ink;

    switch (mood) {
      case ChispaMood.cheer:
        // Happy squeezed eyes (∩) + open mouth + heart flame.
        for (final dir in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCircle(
              center: Offset(cx + dir * eyeDx, eyeY),
              radius: r * 0.2,
            ),
            math.pi,
            math.pi,
            false,
            line,
          );
        }
        _mouthOpen(canvas, Offset(cx, headCenter.dy + r * 0.38), r * 0.22);
        // Heart flame floats by the cheek now that the body is below.
        _heart(canvas, Offset(cx + r * 1.05, headCenter.dy + r * 0.15),
            r * 0.16);
      case ChispaMood.sleepy:
        // Calm closed eyes (∪) + tiny mouth + smoke rings.
        for (final dir in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCircle(
              center: Offset(cx + dir * eyeDx, eyeY),
              radius: r * 0.18,
            ),
            0,
            math.pi,
            false,
            line,
          );
        }
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(cx, headCenter.dy + r * 0.42),
            radius: r * 0.12,
          ),
          0,
          math.pi,
          false,
          line,
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(cx + r * (0.55 + i * 0.22), headCenter.dy - r * (0.55 + i * 0.3)),
            r * (0.1 + i * 0.03),
            Paint()
              ..color = _ink.withValues(alpha: 0.55 - i * 0.15)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, r * 0.05),
          );
        }
      case ChispaMood.thinking:
        // Eyes looking up + small "o" mouth.
        _eyesOpen(canvas, white, black, cx, eyeY, eyeDx, r,
            pupilDy: -r * 0.1);
        canvas.drawCircle(
          Offset(cx, headCenter.dy + r * 0.42),
          r * 0.07,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, r * 0.06),
        );
      case ChispaMood.proud:
        // Half-lidded eyes + smirk shifted to one side.
        _eyesOpen(canvas, white, black, cx, eyeY, eyeDx, r);
        for (final dir in [-1.0, 1.0]) {
          canvas.drawLine(
            Offset(cx + dir * eyeDx - r * 0.2, eyeY - r * 0.32),
            Offset(cx + dir * eyeDx + r * 0.2, eyeY - r * 0.3),
            line,
          );
        }
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(cx + r * 0.08, headCenter.dy + r * 0.36),
            radius: r * 0.24,
          ),
          math.pi * 0.1,
          math.pi * 0.75,
          false,
          line,
        );
      case ChispaMood.discover:
        // Wide eyes + "o" mouth + sparkle.
        _eyesOpen(canvas, white, black, cx, eyeY, eyeDx, r,
            pupilScale: 0.7);
        canvas.drawCircle(
          Offset(cx, headCenter.dy + r * 0.42),
          r * 0.09,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, r * 0.06),
        );
        _sparkle(canvas, Offset(cx + r * 0.85, headCenter.dy - r * 0.75),
            r * 0.22);
      case ChispaMood.encourage:
        // Big eyes, raised brows, wide smile.
        _eyesOpen(canvas, white, black, cx, eyeY, eyeDx, r);
        for (final dir in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCircle(
              center: Offset(cx + dir * eyeDx, eyeY - r * 0.42),
              radius: r * 0.18,
            ),
            math.pi * 1.15,
            math.pi * 0.7,
            false,
            line,
          );
        }
        _smile(canvas, Offset(cx, headCenter.dy + r * 0.34), r * 0.26);
      case ChispaMood.greeting:
        _eyesOpen(canvas, white, black, cx, eyeY, eyeDx, r);
        _smile(canvas, Offset(cx, headCenter.dy + r * 0.34), r * 0.24);
    }
  }

  /// One small orange wing, sticking out of the body's side.
  void _wing(Canvas canvas, double cx, double s, double dir) {
    final wing = Path()
      ..moveTo(cx + dir * s * 0.20, s * 0.62)
      ..quadraticBezierTo(
          cx + dir * s * 0.38, s * 0.50, cx + dir * s * 0.34, s * 0.68)
      ..quadraticBezierTo(
          cx + dir * s * 0.30, s * 0.76, cx + dir * s * 0.20, s * 0.72)
      ..close();
    canvas.drawPath(wing, Paint()..color = _hornOrange);
    canvas.drawPath(
      wing,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.02)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _eyesOpen(Canvas canvas, Paint white, Paint black, double cx,
      double eyeY, double eyeDx, double r,
      {double pupilDy = 0, double pupilScale = 1}) {
    for (final dir in [-1.0, 1.0]) {
      final center = Offset(cx + dir * eyeDx, eyeY);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: r * 0.44, height: r * 0.6),
        white,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(0, pupilDy),
          width: r * 0.2 * pupilScale,
          height: r * 0.3 * pupilScale,
        ),
        black,
      );
    }
  }

  void _smile(Canvas canvas, Offset center, double radius) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, radius * 0.12)
        ..strokeCap = StrokeCap.round,
    );
  }

  void _mouthOpen(Canvas canvas, Offset center, double radius) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.5, height: radius * 1.7),
      Paint()..color = _ink,
    );
  }

  void _heart(Canvas canvas, Offset center, double s) {
    final path = Path()
      ..moveTo(center.dx, center.dy + s)
      ..cubicTo(center.dx - s * 1.2, center.dy - s * 0.1,
          center.dx - s * 0.7, center.dy - s, center.dx, center.dy - s * 0.3)
      ..cubicTo(center.dx + s * 0.7, center.dy - s,
          center.dx + s * 1.2, center.dy - s * 0.1, center.dx, center.dy + s)
      ..close();
    canvas.drawPath(path, Paint()..color = _hornOrange);
  }

  void _sparkle(Canvas canvas, Offset center, double s) {
    final path = Path()
      ..moveTo(center.dx, center.dy - s)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + s, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + s)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - s, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - s)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC93C));
  }

  @override
  bool shouldRepaint(covariant _ChispaPainter oldDelegate) =>
      oldDelegate.mood != mood;
}
