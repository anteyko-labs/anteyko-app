import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'platform/prefs_stub.dart' if (dart.library.js_interop) 'platform/prefs_web.dart' as platform;

/// Системные настройки, которые Flutter сам не отдаёт:
/// «Понижение прозрачности» и «Увеличение контраста» (iOS / браузер).
/// Уменьшение движения Flutter знает сам — см. [SystemLook.reduceMotion].
class SystemPrefs extends ChangeNotifier {
  bool reduceTransparency = false;
  bool increaseContrast = false;

  static const _channel = MethodChannel('anteyko/accessibility');

  Future<void> init() async {
    if (kIsWeb) {
      platform.watchMediaQueries((transparency, contrast) => _set(transparency, contrast));
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Нативный мост в ios/Runner/AppDelegate.swift. Сообщает и об изменениях.
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') _apply(call.arguments);
      });
      try {
        _apply(await _channel.invokeMethod('get'));
      } on MissingPluginException {
        // Старая сборка без моста — просто работаем с прозрачностью.
      }
    }
  }

  void _apply(Object? args) {
    final m = (args as Map?) ?? const {};
    _set(m['reduceTransparency'] == true, m['increaseContrast'] == true);
  }

  void _set(bool transparency, bool contrast) {
    if (transparency == reduceTransparency && contrast == increaseContrast) return;
    reduceTransparency = transparency;
    increaseContrast = contrast;
    notifyListeners();
  }
}

final systemPrefs = SystemPrefs();

/// Красит фон веб-страницы под текущий экран (на телефоне это полоски сверху/снизу).
void syncPageColor(Color c) {
  if (kIsWeb) WidgetsBinding.instance.addPostFrameCallback((_) => platform.setPageColor(c.toARGB32()));
}

/// Доступ к системному «виду» из виджетов. Перестраивает дерево при смене настроек.
/// [premium] — включены ли анимации и «стекло» (функция тарифа «Анимации и стекло»).
class SystemLook extends InheritedNotifier<SystemPrefs> {
  final bool premium;
  SystemLook({super.key, this.premium = true, required super.child}) : super(notifier: systemPrefs);

  @override
  bool updateShouldNotify(SystemLook oldWidget) => super.updateShouldNotify(oldWidget) || oldWidget.premium != premium;

  static SystemLook? _w(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SystemLook>();

  static SystemPrefs _of(BuildContext context) => _w(context)?.notifier ?? systemPrefs;

  static bool premiumDesign(BuildContext context) => _w(context)?.premium ?? true;

  /// Сплошные панели: «Понижение прозрачности» в системе или тариф без «стекла».
  static bool reduceTransparency(BuildContext context) => _of(context).reduceTransparency || !premiumDesign(context);

  static bool highContrast(BuildContext context) => _of(context).increaseContrast || MediaQuery.highContrastOf(context);

  /// Без анимаций: «Уменьшение движения» в системе или тариф без анимаций.
  static bool reduceMotion(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || !premiumDesign(context);
}
