import 'dart:math';

import 'package:flutter/material.dart';

import '../system_prefs.dart';

/// Одноразовый залп конфетти из верхней части экрана.
/// Не показывается, если в системе включено «Уменьшение движения».
class Confetti extends StatefulWidget {
  final int count;
  const Confetti({super.key, this.count = 80});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _rnd = Random(7);
  late final List<_Piece> _pieces = List.generate(widget.count, (_) => _Piece.random(_rnd));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !SystemLook.reduceMotion(context)) {
      _started = true;
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final colors = [
      s.primary,
      s.tertiary,
      s.secondary,
      const Color(0xFFFFC53D),
      const Color(0xFF36CFC9),
      const Color(0xFFFF7A9C),
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value, colors, _c.isAnimating || _c.isCompleted ? 1 : 0),
        ),
      ),
    );
  }
}

class _Piece {
  final double x, vx, vy, spin, size, color, shape;
  _Piece(this.x, this.vx, this.vy, this.spin, this.size, this.color, this.shape);

  factory _Piece.random(Random r) => _Piece(
    0.3 + r.nextDouble() * 0.4,
    (r.nextDouble() - 0.5) * 1.6,
    -(0.9 + r.nextDouble() * 0.9),
    (r.nextDouble() - 0.5) * 18,
    6 + r.nextDouble() * 7,
    r.nextDouble(),
    r.nextDouble(),
  );
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  final List<Color> colors;
  final double visible;
  _ConfettiPainter(this.pieces, this.t, this.colors, this.visible);

  @override
  void paint(Canvas canvas, Size size) {
    if (visible == 0 || t == 0 || t == 1) return;
    final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
    for (final p in pieces) {
      // Простая баллистика: вылет вверх, гравитация, лёгкое сопротивление.
      final time = t * 2.2;
      final x = size.width * (p.x + p.vx * time * 0.35);
      final y = size.height * 0.28 + size.height * (p.vy * time * 0.55 + 0.6 * time * time * 0.5);
      final paint = Paint()..color = colors[(p.color * colors.length).floor() % colors.length].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * time);
      if (p.shape < 0.5) {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.35, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
