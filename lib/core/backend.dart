import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'catalog_repository.dart';
import 'features.dart';
import 'models.dart';
import 'order_service.dart';

/// Всё, что приложению нужно от сервера: каталог, настройки (тариф и функции),
/// отзывы и отправка заказов. Реализации:
/// • [AssetBackend] — каталог из файла, без админки;
/// • LocalStore — база в браузере/на устройстве, с админкой (демо витрины);
/// • SupabaseBackend — настоящий сервер.
abstract class ShopBackend implements CatalogRepository, OrderSubmitter {
  Future<AppSettings> loadSettings();
  Future<List<Review>> loadReviews();
  Future<void> addReview(Review review);

  /// Статусы заказов этого устройства, если сервер их отдаёт.
  Future<Map<String, String>> orderStatuses(List<String> ids) async => const {};

  /// Сигнал «данные изменились» (например, правка в админке).
  Listenable? get changes => null;
}

class AssetBackend extends ShopBackend {
  final String path;
  final OrderSubmitter submitter;
  final AppSettings settings;
  final _reviews = <Review>[];

  AssetBackend(
    this.path, {
    this.submitter = const MessengerOrderSubmitter(),
    this.settings = const AppSettings(promoCodes: AppSettings.demoPromoCodes),
  });

  @override
  Future<Catalog> load() async => Catalog.fromJson(jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>);

  @override
  Future<String?> submit(Order order) => submitter.submit(order);

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<List<Review>> loadReviews() async => List.of(_reviews);

  @override
  Future<void> addReview(Review review) async => _reviews.add(review);
}
