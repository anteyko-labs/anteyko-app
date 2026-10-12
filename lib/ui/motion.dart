import 'package:flutter/material.dart';

import 'system_prefs.dart';

/// Фоновые бесконечные анимации (автопрокрутка баннеров, «дышащие» фоны).
/// В тестах выключаются, чтобы pumpAndSettle не ждал вечно.
bool ambientAnimations = true;

const motionFast = Duration(milliseconds: 180);
const motionMedium = Duration(milliseconds: 320);
const motionSlow = Duration(milliseconds: 600);
const motionCurve = Curves.easeOutCubic;

/// Появление снизу с затуханием. [index] даёт задержку для «волны» в списках.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Offset offset;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 24),
    this.duration = motionSlow,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  // Задержка «волны» — часть самой анимации, без таймеров.
  late final int _delayMs = widget.index.clamp(0, 10) * 60;
  late final _c = AnimationController(
    vsync: this,
    duration: widget.duration + Duration(milliseconds: _delayMs),
  )..forward();
  late final _a = CurvedAnimation(
    parent: _c,
    curve: Interval(_delayMs / (_delayMs + widget.duration.inMilliseconds), 1, curve: motionCurve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // «Уменьшение движения» в системе — сразу показываем без анимации.
    if (SystemLook.reduceMotion(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _a.value,
      child: Transform.translate(offset: widget.offset * (1 - _a.value), child: child),
    ),
  );
}

/// Пружинящее уменьшение при нажатии.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null ? null : (_) => _set(true),
    onTapCancel: () => _set(false),
    onTapUp: (_) => _set(false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down && !SystemLook.reduceMotion(context) ? widget.scale : 1,
      duration: _down ? const Duration(milliseconds: 90) : motionMedium,
      curve: _down ? Curves.easeOut : Curves.elasticOut,
      child: widget.child,
    ),
  );
}

/// «Подпрыгивает», когда меняется [value] (например, счётчик корзины).
class BounceOnChange extends StatefulWidget {
  final Object value;
  final Widget child;
  const BounceOnChange({super.key, required this.value, required this.child});

  @override
  State<BounceOnChange> createState() => _BounceOnChangeState();
}

class _BounceOnChangeState extends State<BounceOnChange> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void didUpdateWidget(BounceOnChange old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !SystemLook.reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) {
      final t = _c.value;
      final s = t == 0 ? 1.0 : 1 + 0.25 * Curves.easeOut.transform(1 - (2 * t - 1).abs());
      return Transform.scale(scale: s, child: child);
    },
  );
}

/// Бесконечная медленная анимация 0→1→0 для фонов. В тестах стоит на месте.
class Breathing extends StatefulWidget {
  final Duration period;
  final Widget Function(BuildContext context, double t) builder;
  const Breathing({super.key, this.period = const Duration(seconds: 6), required this.builder});

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = ambientAnimations && !SystemLook.reduceMotion(context);
    if (on && !_c.isAnimating) _c.repeat(reverse: true);
    if (!on && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, Curves.easeInOut.transform(_c.value)));
}

/// Плавный вход экрана: затухание + лёгкий подъём и масштаб.
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inA = CurvedAnimation(parent: animation, curve: motionCurve, reverseCurve: Curves.easeInCubic);
    final outA = CurvedAnimation(parent: secondaryAnimation, curve: motionCurve);
    return AnimatedBuilder(
      animation: Listenable.merge([inA, outA]),
      child: child,
      builder: (_, child) => Opacity(
        opacity: inA.value,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - inA.value)),
          child: Transform.scale(scale: 1 - 0.03 * outA.value, child: child),
        ),
      ),
    );
  }
}
