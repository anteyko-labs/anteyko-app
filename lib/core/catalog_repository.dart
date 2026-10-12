import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

/// Источник каталога. По умолчанию — JSON из assets.
/// Для API/CMS клиента: реализуйте свой класс (например, HttpCatalogRepository)
/// и передайте его в AppState в main.dart.
abstract class CatalogRepository {
  Future<Catalog> load();
}

class AssetCatalogRepository implements CatalogRepository {
  final String path;
  const AssetCatalogRepository(this.path);

  @override
  Future<Catalog> load() async {
    final raw = await rootBundle.loadString(path);
    return Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
