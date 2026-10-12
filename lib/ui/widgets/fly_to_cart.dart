import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../screens/shell.dart';
import '../system_prefs.dart';
import 'common.dart';

/// Кружок с иконкой товара «перелетает» по дуге от [from] к иконке корзины.
void flyToCart(BuildContext from, Product product) {
  if (SystemLook.reduceMotion(from)) return;
  final box = from.findRenderObject() as RenderBox?;
  final target = ShellNav.cartPosition(from);
  final overlay = Overlay.maybeOf(from, rootOverlay: true);
  if (box == null || !box.attached || target == null || overlay == null) return;

  final start = box.localToGlobal(box.size.center(Offset.zero));
  final cat = AppState.of(from).catalog?.category(product.categoryId);
  final color = cat?.color ?? Theme.of(from).colorScheme.primary;
  final icon = categoryIcon(cat?.icon);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Flyer(start: start, end: target, color: color, icon: icon, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Flyer extends StatefulWidget {
  final Offset start;
  final Offset end;
  final Color color;
  final IconData icon;
  final VoidCallback onDone;
  const _Flyer({required this.start, required this.end, required this.color, required this.icon, required this.onDone});

  @override
  State<_Flyer> createState() => _FlyerState();
}

class _FlyerState extends State<_Flyer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final t = Curves.easeInOutCubic.transform(_c.value);
      // Квадратичная кривая Безье: подъём вверх и падение в корзину.
      final control = Offset((widget.start.dx + widget.end.dx) / 2, widget.start.dy - 160);
      final p = Offset(
        (1 - t) * (1 - t) * widget.start.dx + 2 * (1 - t) * t * control.dx + t * t * widget.end.dx,
        (1 - t) * (1 - t) * widget.start.dy + 2 * (1 - t) * t * control.dy + t * t * widget.end.dy,
      );
      final scale = 1 - 0.55 * t;
      const size = 46.0;
      return Positioned(
        left: p.dx - size / 2,
        top: p.dy - size / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: t > 0.85 ? (1 - t) / 0.15 : 1,
            child: Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: t * 1.2,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Для удобства: добавить и запустить полёт одним вызовом.
extension FlyAdd on AppState {
  void addAndFly(BuildContext from, Product p, {Map<String, String> options = const {}, int quantity = 1}) {
    flyToCart(from, p);
    addToCart(p.id, options: options, quantity: quantity);
  }
}
