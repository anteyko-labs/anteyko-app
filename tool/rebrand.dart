// Переименование приложения под клиента: название на иконке и bundle id.
//
//   dart run tool/rebrand.dart --name "Мой магазин" --id kg.myshop.app
//
// Меняет: Android (label, applicationId, namespace, пакет MainActivity),
// iOS (CFBundleDisplayName, PRODUCT_BUNDLE_IDENTIFIER) и brand.appName.
import 'dart:io';

void main(List<String> args) {
  String? arg(String name) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final name = arg('name');
  final id = arg('id');
  if (name == null && id == null) {
    stderr.writeln('Использование: dart run tool/rebrand.dart --name "Название" --id com.company.app');
    exit(64);
  }
  if (id != null && !RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(id)) {
    stderr.writeln('Некорректный id: $id (пример: kg.myshop.app)');
    exit(64);
  }

  final gradle = File('android/app/build.gradle.kts');
  final oldId = RegExp(r'applicationId = "([^"]+)"').firstMatch(gradle.readAsStringSync())!.group(1)!;

  if (name != null) {
    _replace('android/app/src/main/AndroidManifest.xml', RegExp(r'android:label="[^"]*"'), 'android:label="${_xml(name)}"');
    _replace(
      'ios/Runner/Info.plist',
      RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*'),
      null,
      (m) => '${m.group(1)}${_xml(name)}',
    );
    _replace('lib/brand/brand_config.dart', RegExp(r"appName: '[^']*'"), "appName: '${name.replaceAll("'", r"\'")}'");
  }

  if (id != null && id != oldId) {
    _replace(gradle.path, RegExp(r'namespace = "[^"]+"'), 'namespace = "$id"');
    _replace(gradle.path, RegExp(r'applicationId = "[^"]+"'), 'applicationId = "$id"');
    _replace(
      'ios/Runner.xcodeproj/project.pbxproj',
      RegExp('PRODUCT_BUNDLE_IDENTIFIER = ${RegExp.escape(oldId)}'),
      'PRODUCT_BUNDLE_IDENTIFIER = $id',
    );

    final kotlinRoot = 'android/app/src/main/kotlin';
    final oldFile = File('$kotlinRoot/${oldId.replaceAll('.', '/')}/MainActivity.kt');
    if (oldFile.existsSync()) {
      final newFile = File('$kotlinRoot/${id.replaceAll('.', '/')}/MainActivity.kt')..createSync(recursive: true);
      newFile.writeAsStringSync(oldFile.readAsStringSync().replaceFirst('package $oldId', 'package $id'));
      oldFile.deleteSync();
      _pruneEmptyDirs(oldFile.parent, Directory(kotlinRoot));
    }
  }

  stdout.writeln('Готово.${name != null ? ' Название: $name.' : ''}${id != null ? ' ID: $id.' : ''}');
  stdout.writeln('Дальше: flutter clean && flutter run');
}

String _xml(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('"', '&quot;');

void _replace(String path, RegExp re, String? to, [String Function(Match)? fn]) {
  final f = File(path);
  final src = f.readAsStringSync();
  if (!re.hasMatch(src)) {
    stderr.writeln('Не найдено в $path: ${re.pattern}');
    return;
  }
  f.writeAsStringSync(fn != null ? src.replaceAllMapped(re, fn) : src.replaceAll(re, to!));
}

void _pruneEmptyDirs(Directory dir, Directory stop) {
  var d = dir;
  while (d.path != stop.path && d.existsSync() && d.listSync().isEmpty) {
    d.deleteSync();
    d = d.parent;
  }
}
