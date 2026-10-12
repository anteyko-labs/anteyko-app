import 'dart:ui';

import 'package:flutter/material.dart';

import 'system_prefs.dart';

/// «Стекло» в духе iOS: размытие того, что под панелью, и полупрозрачная заливка.
/// Следует настройкам системы:
/// • «Понижение прозрачности» → сплошная заливка без размытия;
/// • «Увеличение контраста» → плотнее заливка и чёткая граница.
class Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color? tint;
  final double opacity;
  final double blur;
  final bool border;
  final List<BoxShadow>? shadow;

  const Glass({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.tint,
    this.opacity = 0.62,
    this.blur = 24,
    this.border = true,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final solid = SystemLook.reduceTransparency(context);
    final contrast = SystemLook.highContrast(context);
    final base = tint ?? scheme.surface;
    final alpha = solid ? 1.0 : (contrast ? (opacity + 0.25).clamp(0.0, 0.95) : opacity);
    final dark = ThemeData.estimateBrightnessForColor(base) == Brightness.dark;

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: base.withValues(alpha: alpha),
        borderRadius: borderRadius,
        border: !border
            ? null
            : Border.all(
                color: contrast ? scheme.outline : (dark ? Colors.white : Colors.black).withValues(alpha: solid ? 0.06 : 0.10),
                width: contrast ? 1.5 : 0.8,
              ),
        // Блик сверху, как у стекла. Без прозрачности — не нужен.
        gradient: solid || contrast
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(base, Colors.white, dark ? 0.10 : 0.35)!.withValues(alpha: alpha),
                  base.withValues(alpha: alpha),
                ],
              ),
      ),
      child: child,
    );

    final body = solid
        ? decorated
        : BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: decorated,
          );

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
      child: ClipRRect(borderRadius: borderRadius, child: body),
    );
  }
}
