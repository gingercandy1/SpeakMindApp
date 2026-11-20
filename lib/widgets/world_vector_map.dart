/// Vector travel maps for all eight worlds (design doc p.1 / p.6).
///
/// Each world's mainline nodes sit on an illustrated scene drawn with
/// [CustomPaint] — no bitmap assets, so it works with the project's S1
/// style (thick ink outlines, flat colour, cream paper):
///
/// * a landmark scene per world at the top (Madrid clock tower, a
///   Mediterranean sailboat, a Mexican pyramid, Andean peaks, the Buenos
///   Aires obelisk, a Camino shell, a film-city marquee, a globe);
/// * a winding dashed route through the node centres, with amber beads
///   between nodes;
/// * soft fog puffs over locked nodes ("you can always see that something
///   is ahead");
/// * a Chispa marker on the empty margin at the current node's row, with
///   a dashed connector to the node;
/// * a breathing amber ring around the current node.
///
/// The fork card after level 5 and hidden nodes stay below the scene,
/// unchanged. The revisit-letter note from [_MainlineNode] is skipped
/// here (fresh profiles have no completed levels anyway).
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../chispa.dart';
import '../levels.dart';
import '../progress.dart';
import '../theme.dart';

/// Vertical distance between two node rows.
const double _kStepY = 104;

/// Height of the illustrated landmark band at the top of the scene.
const double _kSkylineH = 164;

/// Horizontal swing of the winding route, as a fraction of the width.
const double _kSwing = 0.30;

/// Node label width (matches [_LevelNodeButton]'s 110).
const double _kNodeW = 110;

/// One world's mainline nodes on its illustrated map.
class WorldVectorMap extends StatelessWidget {
  const WorldVectorMap({
    super.key,
    required this.world,
    required this.nodes,
    required this.graph,
    required this.progress,
    required this.nodeBuilder,
  });

  final WorldInfo world;
  final List<LevelNode> nodes;
  final LevelGraph graph;
  final ProgressStore progress;

  /// Builds the tappable node circle for one level (supplied by the map
  /// page so the node keeps its existing behaviour and look).
  final Widget Function(LevelNode node, int index, bool isCurrent) nodeBuilder;

  @override
  Widget build(BuildContext context) {
    final currentId = progress.currentLevel(graph)?.id;
    final currentIndex = nodes.indexWhere((n) => n.id == currentId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final positions = _nodePositions(nodes.length, width);
        final height = _sceneHeight(nodes.length);
        // Chispa marker: empty margin on the opposite side of the
        // current node's row.
        Offset? marker;
        if (currentIndex >= 0) {
          final cx = positions[currentIndex].dx;
          final side = cx > width / 2 ? -1.0 : 1.0;
          marker = Offset(
            width / 2 + side * (width / 2 - 40),
            positions[currentIndex].dy,
          );
        }
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _WorldScenePainter(
                    worldId: world.id,
                    width: width,
                    height: height,
                    positions: positions,
                    marker: marker,
                    markerTarget:
                        currentIndex >= 0 ? positions[currentIndex] : null,
                  ),
                ),
              ),
              for (var i = 0; i < nodes.length; i++)
                Positioned(
                  left: positions[i].dx - _kNodeW / 2,
                  top: positions[i].dy - 28,
                  child: SizedBox(
                    width: _kNodeW,
                    child: nodeBuilder(
                        nodes[i], i, nodes[i].id == currentId),
                  ),
                ),
              if (currentIndex >= 0)
                Positioned(
                  left: positions[currentIndex].dx - 48,
                  top: positions[currentIndex].dy - 48,
                  child: const IgnorePointer(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: _PulseRing(),
                    ),
                  ),
                ),
              if (marker != null)
                Positioned(
                  left: marker.dx - 36,
                  top: marker.dy - 36,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ChispaFace(mood: ChispaMood.greeting, size: 44),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: SpeakMindColors.amber,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: SpeakMindColors.ink, width: 1.5),
                        ),
                        child: const Text(
                          '你在这里',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: SpeakMindColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _WorldFogPainter(
                      positions: positions,
                      locked: [
                        for (final n in nodes) !progress.isUnlocked(n.id),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<Offset> _nodePositions(int count, double width) {
  final center = width / 2;
  return [
    for (var i = 0; i < count; i++)
      Offset(
        center + math.sin(i * 0.85) * width * _kSwing,
        _kSkylineH + 32 + i * _kStepY,
      ),
  ];
}

double _sceneHeight(int count) =>
    _kSkylineH + 32 + (count - 1) * _kStepY + 84;

/// Breathing amber ring around the current node (doc p.6).
class _PulseRing extends StatefulWidget {
  const _PulseRing();

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: _PulseRingPainter(progress: _c.value),
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  _PulseRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = SpeakMindColors.amber.withValues(alpha: (1 - progress) * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 30 + progress * 16, paint);
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.progress != progress;
}

/// Background layer: parchment card, the world's landmark scene, winding
/// dashed route with amber beads, and the dashed connector to the Chispa
/// marker.
class _WorldScenePainter extends CustomPainter {
  _WorldScenePainter({
    required this.worldId,
    required this.width,
    required this.height,
    required this.positions,
    required this.marker,
    required this.markerTarget,
  });

  final int worldId;
  final double width;
  final double height;
  final List<Offset> positions;
  final Offset? marker;
  final Offset? markerTarget;

  static const _ink = SpeakMindColors.ink;

  Paint get _stroke => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Offset.zero & Size(width, height),
      const Radius.circular(20),
    );
    canvas.drawRRect(card, Paint()..color = const Color(0xFFF6E9CB));
    canvas.drawRRect(
        card,
        Paint()
          ..color = _ink.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    _paintLandmark(canvas);
    _paintRoute(canvas);
    if (marker != null && markerTarget != null) {
      _paintConnector(canvas, marker!, markerTarget!);
    }
  }

  void _paintLandmark(Canvas canvas) {
    switch (worldId) {
      case 1:
        _madrid(canvas);
      case 2:
        _barcelona(canvas);
      case 3:
        _mexico(canvas);
      case 4:
        _andes(canvas);
      case 5:
        _buenosAires(canvas);
      case 6:
        _camino(canvas);
      case 7:
        _filmCity(canvas);
      default:
        _global(canvas);
    }
  }

  void _groundLine(Canvas canvas) {
    canvas.drawLine(
      Offset(0, _kSkylineH),
      Offset(width, _kSkylineH),
      Paint()
        ..color = _ink
        ..strokeWidth = 2.5,
    );
  }

  void _sun(Canvas canvas, Offset c) {
    final sunPaint = Paint()..color = SpeakMindColors.amber;
    canvas.drawCircle(c, 24, sunPaint);
    canvas.drawCircle(c, 24, _stroke);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * 30;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * 38;
      canvas.drawLine(p1, p2, _stroke);
    }
  }

  void _cloud(Canvas canvas, Offset c, double scale) {
    final paint = Paint()..color = Colors.white;
    canvas.drawCircle(c, 14 * scale, paint);
    canvas.drawCircle(c + Offset(14 * scale, 4 * scale), 11 * scale, paint);
    canvas.drawCircle(c + Offset(-14 * scale, 5 * scale), 10 * scale, paint);
    canvas.drawOval(
      Rect.fromCenter(
          center: c + Offset(0, 7 * scale), width: 52 * scale, height: 16 * scale),
      paint,
    );
  }

  void _bird(Canvas canvas, Offset c) {
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(c.dx - 7, c.dy)
      ..quadraticBezierTo(c.dx - 3, c.dy - 6, c.dx, c.dy)
      ..quadraticBezierTo(c.dx + 3, c.dy - 6, c.dx + 7, c.dy);
    canvas.drawPath(path, paint);
  }

  void _tree(Canvas canvas, Offset base) {
    canvas.drawRect(
      Rect.fromCenter(
          center: base + const Offset(0, -8), width: 5, height: 16),
      Paint()..color = const Color(0xFF7A4A21),
    );
    canvas.drawCircle(base + const Offset(0, -22), 12,
        Paint()..color = SpeakMindColors.actionGreen);
    canvas.drawCircle(
      base + const Offset(0, -22),
      12,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _building(Canvas canvas, double x, double w, double h, Color color,
      {required _Roof roof, required int windows}) {
    const base = _kSkylineH;
    if (roof == _Roof.pitched) {
      final roofPath = Path()
        ..moveTo(x - 4, base - h)
        ..lineTo(x + w / 2, base - h - 22)
        ..lineTo(x + w + 4, base - h)
        ..close();
      canvas.drawPath(roofPath, Paint()..color = SpeakMindColors.deepTeal);
      canvas.drawPath(roofPath, _stroke);
    } else {
      canvas.drawRect(
        Rect.fromLTWH(x - 3, base - h - 6, w + 6, 6),
        Paint()..color = _ink,
      );
    }
    final body = Rect.fromLTWH(x, base - h, w, h);
    canvas.drawRect(body, Paint()..color = color);
    canvas.drawRect(body, _stroke);
    final gap = w / (windows + 1);
    for (var i = 1; i <= windows; i++) {
      canvas.drawCircle(
        Offset(x + gap * i, base - h + 18),
        5,
        Paint()..color = _ink,
      );
    }
    final door = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(x + w / 2, base - 12), width: 14, height: 24),
      const Radius.circular(7),
    );
    canvas.drawRRect(door, Paint()..color = _ink);
  }

  /// W1 Madrid: sun, clouds, flat-colour buildings with a Puerta del Sol
  /// clock tower, trees.
  void _madrid(Canvas canvas) {
    _sun(canvas, Offset(width - 56, 52));
    _cloud(canvas, const Offset(64, 46), 1.0);
    _cloud(canvas, Offset(width - 150, 96), 0.8);
    _cloud(canvas, const Offset(150, 118), 0.7);
    _bird(canvas, Offset(width / 2 - 10, 60));
    _bird(canvas, Offset(width / 2 + 26, 78));
    const base = _kSkylineH;
    _building(canvas, 10, 62, 62, SpeakMindColors.terracotta,
        roof: _Roof.pitched, windows: 2);
    _tower(canvas, 80, 52, 98);
    _building(canvas, 140, 72, 56, SpeakMindColors.deepTeal,
        roof: _Roof.flat, windows: 3);
    _building(canvas, 220, 60, 74, SpeakMindColors.terracotta,
        roof: _Roof.pitched, windows: 2);
    _building(canvas, 288, 58, 58, const Color(0xFFD98E32),
        roof: _Roof.flat, windows: 2);
    _groundLine(canvas);
    _tree(canvas, const Offset(138, base - 2));
    _tree(canvas, Offset(width - 14, base - 2));
  }

  /// Clock tower (Puerta del Sol): tall ochre tower with a clock face.
  void _tower(Canvas canvas, double x, double w, double h) {
    const base = _kSkylineH;
    final roofPath = Path()
      ..moveTo(x - 4, base - h)
      ..lineTo(x + w / 2, base - h - 18)
      ..lineTo(x + w + 4, base - h)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = SpeakMindColors.terracotta);
    canvas.drawPath(roofPath, _stroke);
    final body = Rect.fromLTWH(x, base - h, w, h);
    canvas.drawRect(body, Paint()..color = const Color(0xFFD98E32));
    canvas.drawRect(body, _stroke);
    final clockC = Offset(x + w / 2, base - h + 24);
    canvas.drawCircle(clockC, 11, Paint()..color = Colors.white);
    canvas.drawCircle(clockC, 11, _stroke);
    final handPaint = Paint()
      ..color = _ink
      ..strokeWidth = 2;
    canvas.drawLine(clockC, clockC + const Offset(0, -6), handPaint);
    canvas.drawLine(clockC, clockC + const Offset(5, 2), handPaint);
    canvas.drawCircle(
        Offset(x + w / 2, base - 14), 5, Paint()..color = _ink);
  }

  /// W2 Barcelona & the Mediterranean: spired church, sea waves and a
  /// sailboat.
  void _barcelona(Canvas canvas) {
    _sun(canvas, Offset(width - 56, 52));
    _cloud(canvas, const Offset(64, 46), 1.0);
    _cloud(canvas, Offset(width - 150, 90), 0.8);
    _bird(canvas, Offset(width / 2 + 20, 62));
    const base = _kSkylineH;
    // Sagrada Família-ish spires.
    for (var i = 0; i < 3; i++) {
      final x = 24.0 + i * 34;
      final h = 96.0 - i * 10;
      final spire = Path()
        ..moveTo(x, base - h + 26)
        ..lineTo(x + 11, base - h - 18)
        ..lineTo(x + 22, base - h + 26)
        ..close();
      canvas.drawPath(spire, Paint()..color = SpeakMindColors.terracotta);
      canvas.drawPath(spire, _stroke);
      final body = Rect.fromLTWH(x, base - h + 26, 22, h - 26);
      canvas.drawRect(body, Paint()..color = const Color(0xFFD98E32));
      canvas.drawRect(body, _stroke);
    }
    // Sea.
    final sea = Rect.fromLTWH(0, base - 26, width, 26);
    canvas.drawRect(sea, Paint()..color = const Color(0xFF7FB8C9));
    for (var i = 0; i < 5; i++) {
      final y = base - 18 + i * 5;
      canvas.drawLine(
        Offset(8 + (i % 2) * 20, y),
        Offset(width - 8 - (i % 2) * 20, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    // Sailboat.
    final bx = width - 96.0;
    final hull = Path()
      ..moveTo(bx - 26, base - 26)
      ..lineTo(bx + 26, base - 26)
      ..lineTo(bx + 16, base - 12)
      ..lineTo(bx - 16, base - 12)
      ..close();
    canvas.drawPath(hull, Paint()..color = SpeakMindColors.deepTeal);
    canvas.drawPath(hull, _stroke);
    final mast = Paint()
      ..color = _ink
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(bx, base - 26), Offset(bx, base - 66), mast);
    final sail = Path()
      ..moveTo(bx + 2, base - 64)
      ..lineTo(bx + 2, base - 28)
      ..lineTo(bx + 24, base - 28)
      ..close();
    canvas.drawPath(sail, Paint()..color = Colors.white);
    canvas.drawPath(sail, _stroke);
    _groundLine(canvas);
  }

  /// W3 Mexico City & market: stepped pyramid and a striped market awning.
  void _mexico(Canvas canvas) {
    _sun(canvas, Offset(width - 56, 52));
    _cloud(canvas, const Offset(64, 46), 1.0);
    _bird(canvas, Offset(width / 2 + 10, 66));
    const base = _kSkylineH;
    // Stepped pyramid.
    for (var i = 0; i < 3; i++) {
      final w = 150.0 - i * 36;
      final h = 30.0;
      final y = base - (i + 1) * h;
      final step = Rect.fromLTWH(30 + (150 - w) / 2, y, w, h);
      canvas.drawRect(
          step, Paint()..color = i.isEven ? const Color(0xFFD98E32) : SpeakMindColors.terracotta);
      canvas.drawRect(step, _stroke);
    }
    // Temple top.
    final top = Rect.fromLTWH(84, base - 108, 42, 18);
    canvas.drawRect(top, Paint()..color = SpeakMindColors.deepTeal);
    canvas.drawRect(top, _stroke);
    // Market awning (right).
    final ax = width - 118.0;
    for (var i = 0; i < 4; i++) {
      final stripe = Path()
        ..moveTo(ax + i * 26, base - 64)
        ..lineTo(ax + (i + 1) * 26, base - 64)
        ..lineTo(ax + (i + 1) * 26, base - 44)
        ..lineTo(ax + i * 26, base - 44)
        ..close();
      canvas.drawPath(
          stripe,
          Paint()
            ..color = i.isEven ? SpeakMindColors.amber : Colors.white);
      canvas.drawPath(stripe, _stroke);
    }
    final pole = Paint()
      ..color = _ink
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(ax + 2, base - 44), Offset(ax + 2, base), pole);
    canvas.drawLine(
        Offset(ax + 102, base - 44), Offset(ax + 102, base), pole);
    _groundLine(canvas);
  }

  /// W4 Peru & Colombia: Andean peaks with snow caps and terraces.
  void _andes(Canvas canvas) {
    _sun(canvas, Offset(width - 56, 52));
    _cloud(canvas, const Offset(70, 44), 0.9);
    _cloud(canvas, Offset(width - 140, 92), 0.7);
    _bird(canvas, Offset(width / 2 - 30, 58));
    const base = _kSkylineH;
    _mountain(canvas, 10, 150, 108);
    _mountain(canvas, 130, 190, 132);
    _mountain(canvas, 250, 120, 92);
    // Terraces at the foot of the middle peak.
    for (var i = 0; i < 3; i++) {
      final w = 120.0 - i * 22;
      final y = base - 8 - i * 8;
      final step = Rect.fromLTWH(150 + (120 - w) / 2, y, w, 8);
      canvas.drawRect(
          step, Paint()..color = SpeakMindColors.actionGreen);
      canvas.drawRect(step, _stroke);
    }
    _groundLine(canvas);
  }

  void _mountain(Canvas canvas, double x, double w, double h) {
    const base = _kSkylineH;
    final peak = Path()
      ..moveTo(x, base)
      ..lineTo(x + w / 2, base - h)
      ..lineTo(x + w, base)
      ..close();
    canvas.drawPath(peak, Paint()..color = SpeakMindColors.deepTeal);
    canvas.drawPath(peak, _stroke);
    // Snow cap.
    final cap = Path()
      ..moveTo(x + w / 2 - 16, base - h + 26)
      ..lineTo(x + w / 2, base - h)
      ..lineTo(x + w / 2 + 16, base - h + 26)
      ..lineTo(x + w / 2 + 7, base - h + 20)
      ..lineTo(x + w / 2, base - h + 28)
      ..lineTo(x + w / 2 - 7, base - h + 20)
      ..close();
    canvas.drawPath(cap, Paint()..color = Colors.white);
  }

  /// W5 Buenos Aires: the obelisk and colourful La Boca houses.
  void _buenosAires(Canvas canvas) {
    _sun(canvas, Offset(width - 56, 52));
    _cloud(canvas, const Offset(64, 46), 1.0);
    _bird(canvas, Offset(width / 2 + 24, 60));
    const base = _kSkylineH;
    // Obelisk (centre-left).
    final obX = 150.0;
    final obelisk = Path()
      ..moveTo(obX, base)
      ..lineTo(obX, base - 96)
      ..lineTo(obX + 16, base - 112)
      ..lineTo(obX + 32, base - 96)
      ..lineTo(obX + 32, base)
      ..close();
    canvas.drawPath(obelisk, Paint()..color = Colors.white);
    canvas.drawPath(obelisk, _stroke);
    // La Boca houses.
    _building(canvas, 16, 58, 54, const Color(0xFFE86A92),
        roof: _Roof.flat, windows: 2);
    _building(canvas, 84, 52, 66, const Color(0xFF5B8DD9),
        roof: _Roof.pitched, windows: 2);
    _building(canvas, 216, 56, 58, const Color(0xFFF2C14E),
        roof: _Roof.flat, windows: 2);
    _building(canvas, 286, 54, 70, const Color(0xFF7FB069),
        roof: _Roof.pitched, windows: 2);
    _groundLine(canvas);
  }

  /// W6 the Camino: rolling hills, a scallop shell waymark and the road.
  void _camino(Canvas canvas) {
    _sun(canvas, Offset(width - 56, 52));
    _cloud(canvas, const Offset(70, 44), 0.9);
    _bird(canvas, Offset(width / 2 - 20, 62));
    const base = _kSkylineH;
    // Rolling hills.
    final hillPaint = Paint()..color = SpeakMindColors.actionGreen;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(60, base + 30), radius: 70),
        math.pi,
        math.pi,
        true,
        hillPaint);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(60, base + 30), radius: 70),
        math.pi,
        math.pi,
        true,
        _stroke);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(width - 40, base + 36), radius: 80),
        math.pi,
        math.pi,
        true,
        Paint()..color = SpeakMindColors.deepTeal);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(width - 40, base + 36), radius: 80),
        math.pi,
        math.pi,
        true,
        _stroke);
    // Scallop shell waymark on a post.
    final post = Paint()
      ..color = _ink
      ..strokeWidth = 3;
    canvas.drawLine(
        Offset(width / 2, base - 44), Offset(width / 2, base), post);
    final shell = Path()
      ..moveTo(width / 2 - 22, base - 44)
      ..arcTo(
          Rect.fromCircle(center: Offset(width / 2, base - 44), radius: 22),
          math.pi,
          math.pi,
          false)
      ..close();
    canvas.drawPath(shell, Paint()..color = SpeakMindColors.amber);
    canvas.drawPath(shell, _stroke);
    for (var i = -2; i <= 2; i++) {
      final a = i * 0.5;
      canvas.drawLine(
        Offset(width / 2, base - 44),
        Offset(width / 2 + math.sin(a) * 20, base - 44 - math.cos(a) * 20),
        Paint()
          ..color = _ink
          ..strokeWidth = 1.5,
      );
    }
    _groundLine(canvas);
  }

  /// W7 film city: cinema facade with a marquee and spotlights.
  void _filmCity(Canvas canvas) {
    const base = _kSkylineH;
    // Spotlights.
    for (final x in [60.0, width - 60]) {
      final beam = Path()
        ..moveTo(x, base)
        ..lineTo(x - 34, 30)
        ..lineTo(x + 34, 30)
        ..close();
      canvas.drawPath(
          beam, Paint()..color = SpeakMindColors.amber.withValues(alpha: 0.25));
    }
    _cloud(canvas, const Offset(70, 40), 0.8);
    // Cinema facade.
    final facade = Rect.fromLTWH(70, base - 96, width - 140, 96);
    canvas.drawRect(facade, Paint()..color = SpeakMindColors.deepTeal);
    canvas.drawRect(facade, _stroke);
    // Marquee.
    final marquee = Rect.fromLTWH(90, base - 78, width - 180, 26);
    canvas.drawRect(marquee, Paint()..color = SpeakMindColors.amber);
    canvas.drawRect(marquee, _stroke);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(110 + i * 18, base - 65),
        4,
        Paint()..color = Colors.white,
      );
    }
    // Doors.
    for (var i = 0; i < 2; i++) {
      final door = RRect.fromRectAndRadius(
        Rect.fromLTWH(120 + i * 60, base - 40, 34, 40),
        const Radius.circular(6),
      );
      canvas.drawRRect(door, Paint()..color = _ink);
    }
    // Clapperboard (right).
    final board = Rect.fromLTWH(width - 96, base - 52, 56, 40);
    canvas.drawRect(board, Paint()..color = Colors.white);
    canvas.drawRect(board, _stroke);
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(width - 96 + i * 19, base - 52),
        Offset(width - 96 + i * 19 + 12, base - 40),
        Paint()
          ..color = _ink
          ..strokeWidth = 3,
      );
    }
    _groundLine(canvas);
  }

  /// W8 around the world: a globe, a little plane and stars.
  void _global(Canvas canvas) {
    _cloud(canvas, const Offset(64, 46), 1.0);
    _cloud(canvas, Offset(width - 140, 96), 0.8);
    const base = _kSkylineH;
    // Globe.
    final c = Offset(width / 2 - 40, base - 62);
    canvas.drawCircle(c, 52, Paint()..color = const Color(0xFF7FB8C9));
    canvas.drawCircle(c, 52, _stroke);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 52, height: 104),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
        c + const Offset(-52, 0), c + const Offset(52, 0),
        Paint()
          ..color = _ink
          ..strokeWidth = 1.5);
    // Continents (two flat blobs).
    canvas.drawOval(
        Rect.fromCenter(center: c + const Offset(-14, -14), width: 34, height: 22),
        Paint()..color = SpeakMindColors.actionGreen);
    canvas.drawOval(
        Rect.fromCenter(center: c + const Offset(16, 16), width: 30, height: 20),
        Paint()..color = SpeakMindColors.actionGreen);
    // Little plane.
    final px = width - 92.0;
    final py = base - 110.0;
    final plane = Path()
      ..moveTo(px, py)
      ..lineTo(px + 30, py + 8)
      ..lineTo(px, py + 12)
      ..lineTo(px + 6, py + 4)
      ..close();
    canvas.drawPath(plane, Paint()..color = SpeakMindColors.terracotta);
    canvas.drawPath(plane, _stroke);
    // Stars.
    for (final s in [
      Offset(40, 36),
      Offset(width - 40, 44),
      Offset(width / 2 + 60, 30),
    ]) {
      canvas.drawCircle(s, 3, Paint()..color = SpeakMindColors.amber);
    }
    _groundLine(canvas);
    _tree(canvas, Offset(56, base - 2));
    _tree(canvas, Offset(width - 40, base - 2));
  }

  void _paintRoute(Canvas canvas) {
    if (positions.length < 2) return;
    final path = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (var i = 1; i < positions.length; i++) {
      final mid = Offset(
        (positions[i - 1].dx + positions[i].dx) / 2,
        (positions[i - 1].dy + positions[i].dy) / 2,
      );
      path.quadraticBezierTo(
          positions[i - 1].dx, positions[i - 1].dy, mid.dx, mid.dy);
    }
    path.lineTo(positions.last.dx, positions.last.dy);
    final dashed = _dashPath(path, 12, 9);
    canvas.drawPath(
      dashed,
      Paint()
        ..color = SpeakMindColors.deepTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // Amber beads between nodes, at t = 0.65 along each segment: below
    // the upper node's title and above the next node's circle, so they
    // never land on the title text.
    for (var i = 0; i + 1 < positions.length; i++) {
      const t = 0.65;
      final bead = Offset(
        positions[i].dx + (positions[i + 1].dx - positions[i].dx) * t,
        positions[i].dy + (positions[i + 1].dy - positions[i].dy) * t,
      );
      canvas.drawCircle(bead, 4.5, Paint()..color = SpeakMindColors.amber);
      canvas.drawCircle(
        bead,
        4.5,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintConnector(Canvas canvas, Offset from, Offset to) {
    final dir = (to - from).normalize();
    final start = from + dir * 38;
    final end = to - dir * 32;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(
      _dashPath(path, 7, 6),
      Paint()
        ..color = _ink.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WorldScenePainter old) =>
      old.worldId != worldId ||
      old.width != width ||
      old.height != height ||
      old.positions.length != positions.length ||
      old.marker != marker;
}

enum _Roof { pitched, flat }

Path _dashPath(Path src, double dash, double gap) {
  final out = Path();
  for (final metric in src.computeMetrics()) {
    var dist = 0.0;
    while (dist < metric.length) {
      final len = math.min(dash, metric.length - dist);
      out.addPath(metric.extractPath(dist, dist + len), Offset.zero);
      dist += dash + gap;
    }
  }
  return out;
}

/// Overlay layer: soft fog puffs over locked nodes. The node titles stay
/// readable below the puffs — you can always see that something is ahead.
class _WorldFogPainter extends CustomPainter {
  _WorldFogPainter({required this.positions, required this.locked});

  final List<Offset> positions;
  final List<bool> locked;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < positions.length; i++) {
      if (!locked[i]) continue;
      final c = positions[i];
      canvas.drawOval(
          Rect.fromCenter(center: c + const Offset(-16, 8), width: 44, height: 24),
          paint);
      canvas.drawOval(
          Rect.fromCenter(center: c + const Offset(12, -6), width: 40, height: 22),
          paint);
      canvas.drawOval(
          Rect.fromCenter(center: c + const Offset(0, 14), width: 48, height: 24),
          paint);
    }
  }

  @override
  bool shouldRepaint(_WorldFogPainter old) =>
      old.positions.length != positions.length || old.locked != locked;
}

extension _OffsetNorm on Offset {
  Offset normalize() {
    final len = distance;
    return len == 0 ? this : this / len;
  }
}
