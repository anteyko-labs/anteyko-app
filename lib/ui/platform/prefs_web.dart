import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// prefers-reduced-transparency / prefers-contrast — то, что iOS и браузеры
/// отдают сайтам из настроек «Универсальный доступ».
void watchMediaQueries(void Function(bool reduceTransparency, bool increaseContrast) onChange) {
  final transparency = web.window.matchMedia('(prefers-reduced-transparency: reduce)');
  final contrast = web.window.matchMedia('(prefers-contrast: more)');
  void emit() => onChange(transparency.matches, contrast.matches);
  final listener = ((web.Event _) => emit()).toJS;
  transparency.addEventListener('change', listener);
  contrast.addEventListener('change', listener);
  emit();
}

/// Цвет страницы и theme-color браузера — чтобы полоски вокруг приложения
/// (под «чёлкой», у индикатора «Домой») были в цвет текущего экрана.
void setPageColor(int argb) {
  final hex = '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  web.document.body?.style.backgroundColor = hex;
  web.document.documentElement?.setAttribute('style', 'background:$hex');
  final meta = web.document.querySelector('meta[name="theme-color"]');
  meta?.setAttribute('content', hex);
}
