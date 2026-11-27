import 'package:flutter/material.dart';

enum _MotifType { puppyPaw, kittenPaw, tinyHeart }

class _MotifSpec {
  final double nx; // Normalized X (0.0 - 1.0)
  final double ny; // Normalized Y (0.0 - 1.0)
  final double size;
  final double angle;
  final _MotifType type;
  final Color color;

  const _MotifSpec({
    required this.nx,
    required this.ny,
    required this.size,
    required this.angle,
    required this.type,
    required this.color,
  });
}

/// Lightweight, deterministic pet-inspired background for the Discover screen.
/// Uses a static [CustomPainter] wrapped in [RepaintBoundary] so it never
/// repaints during card swipe animations.
class DiscoverPawBackground extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const DiscoverPawBackground({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DiscoverPawPainter(),
              size: Size.infinite,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DiscoverPawPainter extends CustomPainter {
  const _DiscoverPawPainter();

  static const Color _sage = Color(0xFF7C9082);
  static const Color _mutedTeal = Color(0xFF2E8B7A);
  static const Color _warmBeige = Color(0xFFCBBBA0);
  static const Color _lightTerracotta = Color(0xFFD97757);

  // Deterministic organic scatter clearly visible in header, margins, corners, and behind the deck.
  static const List<_MotifSpec> _motifs = [
    // Top header band
    _MotifSpec(nx: 0.05, ny: 0.06, size: 26, angle: -0.35, type: _MotifType.kittenPaw, color: Color(0x557C9082)),
    _MotifSpec(nx: 0.43, ny: 0.05, size: 17, angle: 0.25, type: _MotifType.tinyHeart, color: Color(0x4AD97757)),
    _MotifSpec(nx: 0.56, ny: 0.09, size: 24, angle: 0.40, type: _MotifType.puppyPaw, color: Color(0x4A2E8B7A)),
    _MotifSpec(nx: 0.94, ny: 0.11, size: 22, angle: -0.24, type: _MotifType.kittenPaw, color: Color(0x5ECBBBA0)),

    // Upper-deck band (above & around stacked card peek)
    _MotifSpec(nx: 0.14, ny: 0.135, size: 25, angle: 0.22, type: _MotifType.puppyPaw, color: Color(0x527C9082)),
    _MotifSpec(nx: 0.34, ny: 0.125, size: 20, angle: -0.28, type: _MotifType.kittenPaw, color: Color(0x4E2E8B7A)),
    _MotifSpec(nx: 0.67, ny: 0.13, size: 16, angle: 0.18, type: _MotifType.tinyHeart, color: Color(0x4AD97757)),
    _MotifSpec(nx: 0.86, ny: 0.14, size: 23, angle: -0.32, type: _MotifType.puppyPaw, color: Color(0x58CBBBA0)),

    // Left margin (visible beside the swipe card)
    _MotifSpec(nx: 0.025, ny: 0.24, size: 25, angle: 0.32, type: _MotifType.puppyPaw, color: Color(0x557C9082)),
    _MotifSpec(nx: 0.03, ny: 0.37, size: 20, angle: -0.45, type: _MotifType.kittenPaw, color: Color(0x4C2E8B7A)),
    _MotifSpec(nx: 0.025, ny: 0.50, size: 15, angle: 0.20, type: _MotifType.tinyHeart, color: Color(0x4AD97757)),
    _MotifSpec(nx: 0.028, ny: 0.63, size: 24, angle: 0.18, type: _MotifType.puppyPaw, color: Color(0x5ECBBBA0)),
    _MotifSpec(nx: 0.032, ny: 0.77, size: 21, angle: -0.26, type: _MotifType.kittenPaw, color: Color(0x527C9082)),

    // Right margin (visible beside the swipe card)
    _MotifSpec(nx: 0.972, ny: 0.25, size: 22, angle: -0.38, type: _MotifType.kittenPaw, color: Color(0x4CD97757)),
    _MotifSpec(nx: 0.97, ny: 0.39, size: 26, angle: 0.26, type: _MotifType.puppyPaw, color: Color(0x557C9082)),
    _MotifSpec(nx: 0.972, ny: 0.53, size: 20, angle: -0.30, type: _MotifType.kittenPaw, color: Color(0x4E2E8B7A)),
    _MotifSpec(nx: 0.968, ny: 0.68, size: 24, angle: 0.35, type: _MotifType.puppyPaw, color: Color(0x5ECBBBA0)),
    _MotifSpec(nx: 0.965, ny: 0.82, size: 16, angle: -0.18, type: _MotifType.tinyHeart, color: Color(0x4AD97757)),

    // Center-area motifs (visible during swipes & empty states)
    _MotifSpec(nx: 0.28, ny: 0.28, size: 25, angle: -0.18, type: _MotifType.kittenPaw, color: Color(0x48CBBBA0)),
    _MotifSpec(nx: 0.68, ny: 0.32, size: 26, angle: 0.36, type: _MotifType.puppyPaw, color: Color(0x457C9082)),
    _MotifSpec(nx: 0.25, ny: 0.54, size: 18, angle: 0.12, type: _MotifType.tinyHeart, color: Color(0x42D97757)),
    _MotifSpec(nx: 0.72, ny: 0.58, size: 24, angle: -0.28, type: _MotifType.kittenPaw, color: Color(0x452E8B7A)),
    _MotifSpec(nx: 0.47, ny: 0.74, size: 26, angle: 0.22, type: _MotifType.puppyPaw, color: Color(0x487C9082)),

    // Bottom band (between card bottom and bottom nav)
    _MotifSpec(nx: 0.11, ny: 0.895, size: 24, angle: 0.34, type: _MotifType.puppyPaw, color: Color(0x557C9082)),
    _MotifSpec(nx: 0.32, ny: 0.91, size: 16, angle: -0.18, type: _MotifType.tinyHeart, color: Color(0x4AD97757)),
    _MotifSpec(nx: 0.54, ny: 0.905, size: 21, angle: -0.25, type: _MotifType.kittenPaw, color: Color(0x4E2E8B7A)),
    _MotifSpec(nx: 0.82, ny: 0.90, size: 23, angle: 0.24, type: _MotifType.puppyPaw, color: Color(0x5ECBBBA0)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Warm ivory-sage gradient base (replaces flat white/cream look)
    final basePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFF3EFE4),
          Color(0xFFEAF0EA),
          Color(0xFFF4EDE2),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    // 2. Soft organic background washes
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.10),
      size.width * 0.38,
      Paint()..color = _sage.withValues(alpha: 0.14),
    );

    canvas.drawCircle(
      Offset(size.width * 0.06, size.height * 0.80),
      size.width * 0.42,
      Paint()..color = _warmBeige.withValues(alpha: 0.18),
    );

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.88),
      size.width * 0.28,
      Paint()..color = _lightTerracotta.withValues(alpha: 0.09),
    );

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.16),
      size.width * 0.26,
      Paint()..color = _mutedTeal.withValues(alpha: 0.08),
    );

    // 3. Scattered paw prints & tiny hearts
    for (final m in _motifs) {
      final center = Offset(m.nx * size.width, m.ny * size.height);
      final paint = Paint()
        ..color = m.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(m.angle);

      switch (m.type) {
        case _MotifType.puppyPaw:
          _drawPuppyPaw(canvas, m.size, paint);
        case _MotifType.kittenPaw:
          _drawKittenPaw(canvas, m.size, paint);
        case _MotifType.tinyHeart:
          _drawTinyHeart(canvas, m.size, paint);
      }

      canvas.restore();
    }
  }

  void _drawPuppyPaw(Canvas canvas, double s, Paint paint) {
    final padPath = Path()
      ..moveTo(0, -s * 0.08)
      ..cubicTo(s * 0.28, -s * 0.08, s * 0.36, s * 0.24, s * 0.20, s * 0.34)
      ..cubicTo(s * 0.08, s * 0.40, -s * 0.08, s * 0.40, -s * 0.20, s * 0.34)
      ..cubicTo(-s * 0.36, s * 0.24, -s * 0.28, -s * 0.08, 0, -s * 0.08)
      ..close();
    canvas.drawPath(padPath, paint);

    const toeAngles = [-0.45, -0.15, 0.15, 0.45];
    final toeOffsets = [
      Offset(-s * 0.33, -s * 0.12),
      Offset(-s * 0.13, -s * 0.30),
      Offset(s * 0.13, -s * 0.30),
      Offset(s * 0.33, -s * 0.12),
    ];

    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(toeOffsets[i].dx, toeOffsets[i].dy);
      canvas.rotate(toeAngles[i]);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.17, height: s * 0.23),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawKittenPaw(Canvas canvas, double s, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.14),
        width: s * 0.44,
        height: s * 0.34,
      ),
      paint,
    );

    final toePositions = [
      Offset(-s * 0.29, -s * 0.09),
      Offset(-s * 0.11, -s * 0.26),
      Offset(s * 0.11, -s * 0.26),
      Offset(s * 0.29, -s * 0.09),
    ];

    for (final pos in toePositions) {
      canvas.drawCircle(pos, s * 0.095, paint);
    }
  }

  void _drawTinyHeart(Canvas canvas, double s, Paint paint) {
    final r = s * 0.42;
    final path = Path()
      ..moveTo(0, r * 0.72)
      ..cubicTo(-r * 1.15, r * 0.05, -r * 0.95, -r * 0.92, 0, -r * 0.30)
      ..cubicTo(r * 0.95, -r * 0.92, r * 1.15, r * 0.05, 0, r * 0.72)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DiscoverPawPainter oldDelegate) => false;
}
