import 'package:flutter/material.dart';

import '../brand/brand_config.dart';
import 'motion.dart';

/// Соседний оттенок цвета — для градиентов, которые не «грязнят».
Color shiftHue(Color c, double degrees, {double lighten = 0}) {
  final h = HSLColor.fromColor(c);
  return h.withHue((h.hue + degrees) % 360).withLightness((h.lightness + lighten).clamp(0, 1)).toColor();
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brand.primaryColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final radius = BorderRadius.circular(brand.cornerRadius);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: brand.fontFamily,
    scaffoldBackgroundColor: scheme.surface,
  );

  // Заголовки — отдельным шрифтом бренда, если он задан.
  final h = brand.headingFont ?? brand.fontFamily;
  TextStyle? head(TextStyle? s, {FontWeight w = FontWeight.w700}) => s?.copyWith(fontFamily: h, fontWeight: w);
  final text = base.textTheme.copyWith(
    displayLarge: head(base.textTheme.displayLarge),
    displayMedium: head(base.textTheme.displayMedium),
    displaySmall: head(base.textTheme.displaySmall),
    headlineLarge: head(base.textTheme.headlineLarge),
    headlineMedium: head(base.textTheme.headlineMedium),
    headlineSmall: head(base.textTheme.headlineSmall),
    titleLarge: head(base.textTheme.titleLarge),
  );

  return base.copyWith(
    textTheme: text,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SoftPageTransitionsBuilder(),
        TargetPlatform.iOS: SoftPageTransitionsBuilder(),
        TargetPlatform.macOS: SoftPageTransitionsBuilder(),
        TargetPlatform.windows: SoftPageTransitionsBuilder(),
        TargetPlatform.linux: SoftPageTransitionsBuilder(),
        TargetPlatform.fuchsia: SoftPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontSize: 22, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: base.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.cornerRadius / 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: -0.1),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.cornerRadius.clamp(4, 16))),
    ),
  );
}
