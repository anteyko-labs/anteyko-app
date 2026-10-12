// Рисует иконки веб-приложения (экран «Домой» на iPhone/Android) из виджета.
//   flutter test tool/generate_icons_test.dart
// Результат: web/icons/*.png и web/favicon.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _ink = Color(0xFF0E0F13);
const _dots = [Color(0xFF2F5BEA), Color(0xFFFF6B2C), Color(0xFFC81E4A), Color(0xFF16A34A), Color(0xFFB0708A)];

/// [safe] — доля холста под логотип (для maskable-иконок Android ≤ 0.8).
Widget icon(double size, {double safe = 1}) => Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF23263A), _ink]),
      ),
      child: Stack(
        children: [
          // Мягкое свечение в цветах демо.
          for (final (i, c) in _dots.indexed)
            Positioned(
              left: size * (0.08 + i * 0.2),
              top: size * (i.isEven ? 0.0 : 0.62),
              child: Container(
                width: size * 0.45,
                height: size * 0.45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [c.withValues(alpha: 0.45), c.withValues(alpha: 0)]),
                ),
              ),
            ),
          Center(
            child: Text(
              'A',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontWeight: FontWeight.w700,
                fontSize: size * 0.5 * safe,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('icons', (t) async {
    final f = FontLoader('Unbounded')
      ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Unbounded-700.ttf').readAsBytesSync())));
    await t.runAsync(f.load);

    Future<void> render(String path, double size, {double safe = 1}) async {
      t.view.physicalSize = Size(size, size);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('icon'),
          child: icon(size, safe: safe),
        ),
      );
      final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('icon')));
      await t.runAsync(() async {
        final img = await ro.toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await render('web/icons/Icon-512.png', 512);
    await render('web/icons/Icon-192.png', 192);
    await render('web/icons/apple-touch-icon.png', 180);
    await render('web/icons/Icon-maskable-512.png', 512, safe: 0.75);
    await render('web/icons/Icon-maskable-192.png', 192, safe: 0.75);
    await render('web/favicon.png', 32);
    t.view.reset();
  });
}
