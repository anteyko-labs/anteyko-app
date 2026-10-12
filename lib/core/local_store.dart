import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand/brand_config.dart';
import 'backend.dart';
import 'features.dart';
import 'models.dart';
import 'order_service.dart';
import 'rows.dart';

/// База приложения на устройстве (в браузере — localStorage).
/// Её же редактирует админка в демо-режиме, поэтому правки сразу видны в приложении.
/// При первом запуске заполняется каталогом из [seedAsset], отзывами и заказами для аналитики.
class LocalStore extends ShopBackend with ChangeNotifier {
  final String id;
  final String seedAsset;
  final OrderSubmitter? alsoSendTo;

  LocalStore({required this.id, required this.seedAsset, this.alsoSendTo});

  List<DbRow> categories = [];
  List<DbRow> products = [];
  List<DbRow> banners = [];
  List<DbRow> orders = [];
  List<DbRow> reviews = [];
  AppSettings settings = const AppSettings(promoCodes: AppSettings.demoPromoCodes);

  Future<void>? _ready;
  Future<void> ensure() => _ready ??= _load();

  String get _key => '$id.db';

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final raw = (await _prefs())?.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        List<DbRow> rows(String k) => [for (final r in j[k] as List? ?? []) Map<String, dynamic>.from(r as Map)];
        categories = rows('categories');
        products = rows('products');
        banners = rows('banners');
        orders = rows('orders');
        reviews = rows('reviews');
        settings = AppSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map? ?? {}));
        return;
      } catch (_) {
        // Повреждённые данные — заполняем заново.
      }
    }
    await _seed();
  }

  Future<void> _seed() async {
    final j = jsonDecode(await rootBundle.loadString(seedAsset)) as Map<String, dynamic>;
    final cats = (j['categories'] as List? ?? []).cast<Map<String, dynamic>>();
    final prods = (j['products'] as List? ?? []).cast<Map<String, dynamic>>();
    final bans = (j['banners'] as List? ?? []).cast<Map<String, dynamic>>();
    categories = [for (final (i, c) in cats.indexed) categoryToRow(c, i)];
    products = [for (final (i, p) in prods.indexed) productToRow(p, i)];
    banners = [for (final (i, b) in bans.indexed) bannerToRow(b, i)];
    settings = const AppSettings(promoCodes: AppSettings.demoPromoCodes);
    final rnd = Random(id.hashCode);
    reviews = _seedReviews(rnd);
    orders = _seedOrders(rnd);
    await save(notify: false);
  }

  /// Вернуть демо к исходному состоянию.
  Future<void> reset() async {
    (await _prefs())?.remove(_key);
    await _seed();
    notifyListeners();
  }

  Future<void> save({bool notify = true}) async {
    (await _prefs())?.setString(
      _key,
      jsonEncode({
        'categories': categories,
        'products': products,
        'banners': banners,
        'orders': orders,
        'reviews': reviews,
        'settings': settings.toJson(),
      }),
    );
    if (notify) notifyListeners();
  }

  // ---------------- ShopBackend ----------------

  @override
  Listenable get changes => this;

  @override
  Future<Catalog> load() async {
    await ensure();
    return catalogFromRows(categories, products, banners);
  }

  @override
  Future<AppSettings> loadSettings() async {
    await ensure();
    return settings;
  }

  @override
  Future<List<Review>> loadReviews() async {
    await ensure();
    return [for (final r in reviews) Review.fromRow(r)].where((r) => r.approved).toList();
  }

  @override
  Future<void> addReview(Review review) async {
    await ensure();
    reviews.insert(0, review.toRow()..['approved'] = false);
    await save();
  }

  @override
  Future<String?> submit(Order order) async {
    await ensure();
    final next = orders.fold<int>(1000, (m, o) => max(m, int.tryParse('${o['id']}') ?? 0)) + 1;
    orders.insert(0, orderToRow(order, id: '$next'));
    await save();
    await alsoSendTo?.submit(order.withId('$next'));
    return '$next';
  }

  @override
  Future<Map<String, String>> orderStatuses(List<String> ids) async {
    await ensure();
    return {
      for (final o in orders)
        if (ids.contains('${o['id']}')) '${o['id']}': o['status'] as String,
    };
  }

  // ---------------- Демо-данные ----------------

  static const _names = [
    'Айгерим',
    'Бакыт',
    'Елена',
    'Тимур',
    'Асель',
    'Нурлан',
    'Мария',
    'Данияр',
    'Алина',
    'Эрлан',
    'Камила',
    'Руслан',
  ];
  static const _good = [
    'Отличное качество, рекомендую!',
    'Всё пришло быстро и аккуратно, спасибо.',
    'Полностью соответствует описанию.',
    'Цена и качество — супер. Буду брать ещё.',
    'Очень понравилось, уже советую друзьям.',
    'Приятный сервис и быстрая доставка.',
  ];
  static const _ok = ['В целом хорошо, но ждали немного дольше обещанного.', 'Нормально, ожидал чуть большего за эту цену.'];

  List<DbRow> _seedReviews(Random rnd) {
    final out = <DbRow>[];
    for (final p in products) {
      if (p['featured'] != true && rnd.nextDouble() < 0.3) continue;
      final n = 1 + rnd.nextInt(p['featured'] == true ? 6 : 3);
      for (var i = 0; i < n; i++) {
        final rating = rnd.nextDouble() < 0.8 ? 5 : (rnd.nextDouble() < 0.7 ? 4 : 3);
        out.add(
          Review(
            id: 'r${p['id']}$i',
            productId: '${p['id']}',
            name: _names[rnd.nextInt(_names.length)],
            rating: rating,
            text: rating >= 4 ? _good[rnd.nextInt(_good.length)] : _ok[rnd.nextInt(_ok.length)],
            createdAt: DateTime.now().subtract(Duration(days: rnd.nextInt(60), hours: rnd.nextInt(24))),
          ).toRow(),
        );
      }
    }
    // Пара отзывов ждёт модерации — чтобы было что показать в админке.
    if (products.isNotEmpty) {
      for (var i = 0; i < 2; i++) {
        out.insert(
          0,
          Review(
            id: 'pending$i',
            productId: '${products[i % products.length]['id']}',
            name: _names[(i + 3) % _names.length],
            rating: 5 - i,
            text: i == 0 ? 'Заказываю второй раз — всё супер!' : 'Хорошо, но упаковку можно лучше.',
            createdAt: DateTime.now().subtract(Duration(hours: 2 + i * 5)),
            approved: false,
          ).toRow(),
        );
      }
    }
    return out;
  }

  /// ~50 заказов за последний месяц — чтобы аналитика в админке была живой.
  List<DbRow> _seedOrders(Random rnd) {
    final priced = products.where((p) => p['price'] != null).toList();
    if (priced.isEmpty) return [];
    final out = <DbRow>[];
    final now = DateTime.now();
    for (var i = 0; i < 52; i++) {
      final days = (pow(rnd.nextDouble(), 1.3) * 30).floor();
      final created = now.subtract(Duration(days: days, hours: rnd.nextInt(12), minutes: rnd.nextInt(60)));
      final lines = <DbRow>[];
      for (var k = 0; k < 1 + rnd.nextInt(3); k++) {
        final p = priced[rnd.nextInt(priced.length)];
        lines.add({
          'productId': p['id'],
          'title': p['title'],
          'options': <String, String>{},
          'price': p['price'],
          'quantity': 1 + rnd.nextInt(2),
        });
      }
      final subtotal = lines.fold<num>(0, (s, l) => s + (l['price'] as num) * (l['quantity'] as num));
      final delivery = rnd.nextDouble() < 0.7;
      final status = days == 0
          ? ['new', 'confirmed', 'delivering'][rnd.nextInt(3)]
          : (rnd.nextDouble() < 0.08 ? 'cancelled' : 'done');
      out.add({
        'created_at': created.toUtc().toIso8601String(),
        'status': status,
        'customer_name': _names[rnd.nextInt(_names.length)],
        'customer_phone': '+996 ${500 + rnd.nextInt(299)} ${100 + rnd.nextInt(899)} ${100 + rnd.nextInt(899)}',
        'address': delivery ? 'ул. Киевская, ${1 + rnd.nextInt(150)}' : '',
        'is_delivery': delivery,
        'payment': ['cash', 'card', 'transfer'][rnd.nextInt(3)],
        'comment': '',
        'lines': lines,
        'subtotal': subtotal,
        'delivery_fee': 0,
        'discount': 0,
        'bonus_spent': 0,
        'total': subtotal,
        'admin_note': '',
      });
    }
    // Номера растут вместе с датой, новые — сверху.
    out.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
    for (final (i, o) in out.indexed) {
      o['id'] = '${1001 + i}';
    }
    return out.reversed.toList();
  }
}

/// База на устройстве для бренда (одна на бренд — её же видит админка).
final _stores = <String, LocalStore>{};
LocalStore localStoreFor(BrandConfig b) => _stores.putIfAbsent(
  b.id,
  () => LocalStore(
    id: b.id,
    seedAsset: b.catalogAsset,
    alsoSendTo: b.checkout.orderChannel == OrderChannel.none ? null : const MessengerOrderSubmitter(),
  ),
);
