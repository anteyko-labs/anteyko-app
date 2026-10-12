import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand/brand_config.dart';
import '../brand/strings.dart';
import 'backend.dart';
import 'features.dart';
import 'models.dart';

/// Всё состояние приложения: каталог, настройки (тариф и функции), корзина,
/// избранное, заказы, бонусы, отзывы. Данные покупателя сохраняются на устройстве.
class AppState extends ChangeNotifier {
  final ShopBackend backend;

  /// Ключ хранения на устройстве — бренд на момент создания (в витрине их несколько).
  final String storageKey = brand.id;

  AppState({required this.backend});

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  Catalog? catalog;
  Object? error;
  bool loading = false;

  AppSettings settings = const AppSettings();
  List<Review> reviews = [];
  Map<String, String> statuses = {};

  /// Растёт при смене настроек — приложение перестраивается целиком.
  int revision = 0;

  final List<CartLine> cart = [];
  final Set<String> favorites = {};
  final List<Order> orders = [];
  Customer customer = const Customer();
  num bonusBalance = 0;

  /// Выбор клиента (если включены «Тёмная тема» и «Русский / English»).
  ThemeMode? themeChoice;
  String? language;

  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _restore();
    } catch (_) {
      // Без хранилища приложение работает, просто ничего не запоминает.
    }
    backend.changes?.addListener(_onBackendChanged);
    await reload();
  }

  @override
  void dispose() {
    backend.changes?.removeListener(_onBackendChanged);
    super.dispose();
  }

  void _onBackendChanged() => reload(silent: true);

  /// Приложение на экране. В витрине состояний несколько — глобальные
  /// настройки (тариф, язык) задаёт только активное.
  static AppState? _active;

  /// Применить настройки этого приложения глобально (тариф, язык).
  void activate() {
    _active = this;
    setAppSettings(settings);
    S.lang = has(Feature.languages) ? (language ?? brand.locale) : brand.locale;
  }

  Future<void> loadCatalog() => reload();

  Future<void> reload({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final (c, s, r) = await (backend.load(), backend.loadSettings(), backend.loadReviews()).wait;
      catalog = c;
      if (s.toJson().toString() != settings.toJson().toString()) revision++;
      settings = s;
      reviews = r;
      _ratings = null;
      cart.removeWhere((l) => catalog!.product(l.productId) == null);
      statuses = Map.of(await backend.orderStatuses([for (final o in orders) o.id]));
      if (_active == null || identical(_active, this)) activate();
    } catch (e) {
      if (!silent) error = e;
    }
    loading = false;
    notifyListeners();
  }

  // ---------------- Корзина ----------------

  int get cartCount => cart.fold(0, (s, l) => s + l.quantity);

  num get subtotal => cart.fold<num>(0, (s, l) {
    final p = catalog?.product(l.productId);
    return s + (p?.price ?? 0) * l.quantity;
  });

  num deliveryFeeFor({required bool isDelivery}) {
    final c = brand.checkout;
    if (!isDelivery) return 0;
    if (c.freeDeliveryFrom != null && subtotal >= c.freeDeliveryFrom!) return 0;
    return c.deliveryFee;
  }

  bool get meetsMinOrder => subtotal >= brand.checkout.minOrder;

  /// Позиция товара без опций (для кнопок +/− прямо на карточке).
  CartLine? plainLine(String productId) => cart.where((l) => l.productId == productId && l.options.isEmpty).firstOrNull;

  int quantityInCart(String productId) => cart.where((l) => l.productId == productId).fold(0, (s, l) => s + l.quantity);

  void addToCart(String productId, {Map<String, String> options = const {}, int quantity = 1}) {
    final line = CartLine(productId: productId, options: Map.of(options), quantity: quantity);
    final existing = cart.where((l) => l.key == line.key).firstOrNull;
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      cart.add(line);
    }
    _changed();
  }

  void setQuantity(CartLine line, int quantity) {
    if (quantity <= 0) {
      cart.remove(line);
    } else {
      line.quantity = quantity;
    }
    _changed();
  }

  void removeLine(CartLine line) {
    cart.remove(line);
    _changed();
  }

  void clearCart() {
    cart.clear();
    _changed();
  }

  // ---------------- Скидки и бонусы ----------------

  /// Скидка по промокоду для текущей корзины (0, если код не подходит).
  num promoDiscount(String? code) {
    if (code == null || !has(Feature.promoCodes)) return 0;
    return settings.promo(code)?.discountFor(subtotal) ?? 0;
  }

  /// Сколько бонусов можно списать: не больше баланса и не больше N% суммы.
  num maxBonusSpend({num discount = 0}) {
    if (!has(Feature.loyalty)) return 0;
    final cap = ((subtotal - discount) * settings.loyaltyMaxSpendPercent / 100).floor();
    return bonusBalance.clamp(0, cap < 0 ? 0 : cap);
  }

  num bonusEarnedFor(num paid) => has(Feature.loyalty) ? (paid * settings.loyaltyPercent / 100).floor() : 0;

  // ---------------- Избранное ----------------

  bool isFavorite(String id) => favorites.contains(id);

  void toggleFavorite(String id) {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    _changed();
  }

  // ---------------- Отзывы ----------------

  Map<String, (double, int)>? _ratings;

  /// Средняя оценка и число отзывов товара.
  (double, int) ratingFor(String productId) {
    _ratings ??= () {
      final sums = <String, (int, int)>{};
      for (final r in reviews) {
        final (s, n) = sums[r.productId] ?? (0, 0);
        sums[r.productId] = (s + r.rating, n + 1);
      }
      return {for (final e in sums.entries) e.key: (e.value.$1 / e.value.$2, e.value.$2)};
    }();
    return _ratings![productId] ?? (0, 0);
  }

  List<Review> reviewsFor(String productId) => reviews.where((r) => r.productId == productId).toList();

  Future<void> addReview(String productId, int rating, String text) async {
    await backend.addReview(
      Review(
        id: 'u${DateTime.now().millisecondsSinceEpoch}',
        productId: productId,
        name: customer.name.isEmpty ? 'Покупатель' : customer.name,
        rating: rating,
        text: text,
        createdAt: DateTime.now(),
        approved: false,
      ),
    );
  }

  // ---------------- Заказы ----------------

  Future<Order> placeOrder({
    required Customer customer,
    required bool isDelivery,
    required String payment,
    required String comment,
    String? promoCode,
    num bonusToSpend = 0,
    String? deliverySlot,
  }) async {
    final c = catalog!;
    final discount = promoDiscount(promoCode);
    final spent = bonusToSpend.clamp(0, maxBonusSpend(discount: discount));
    final paid = subtotal - discount - spent;
    final draft = Order(
      id: (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0'),
      createdAt: DateTime.now(),
      lines: [
        for (final l in cart)
          if (c.product(l.productId) case final p?)
            OrderLine(productId: p.id, title: p.title, options: l.options, price: p.price ?? 0, quantity: l.quantity),
      ],
      customer: customer,
      isDelivery: isDelivery,
      payment: payment,
      comment: comment,
      subtotal: subtotal,
      deliveryFee: deliveryFeeFor(isDelivery: isDelivery),
      discount: discount,
      promoCode: discount > 0 ? promoCode!.trim().toUpperCase() : null,
      bonusSpent: spent,
      bonusEarned: bonusEarnedFor(paid),
      deliverySlot: isDelivery && has(Feature.deliverySlots) ? deliverySlot : null,
    );
    final serverId = await backend.submit(draft);
    final order = serverId == null ? draft : draft.withId(serverId);
    this.customer = customer;
    bonusBalance = bonusBalance - order.bonusSpent + order.bonusEarned;
    orders.insert(0, order);
    statuses[order.id] = 'new';
    cart.clear();
    _changed();
    return order;
  }

  void repeatOrder(Order order) {
    for (final l in order.lines) {
      if (catalog?.product(l.productId) != null) {
        addToCart(l.productId, options: l.options, quantity: l.quantity);
      }
    }
  }

  // ---------------- Тема и язык клиента ----------------

  void setThemeChoice(ThemeMode? m) {
    themeChoice = m;
    revision++;
    _changed();
  }

  void setLanguage(String code) {
    language = code;
    activate();
    revision++;
    _changed();
  }

  /// Тема с учётом выбора клиента (если функция включена).
  ThemeMode get themeMode => has(Feature.themeSwitch) ? (themeChoice ?? brand.themeMode) : brand.themeMode;

  // ---------------- Хранение ----------------

  void _changed() {
    notifyListeners();
    _persist();
  }

  void _persist() {
    final p = _prefs;
    if (p == null) return;
    final k = storageKey;
    p.setString('$k.cart', jsonEncode([for (final l in cart) l.toJson()]));
    p.setStringList('$k.favorites', favorites.toList());
    p.setString('$k.orders', jsonEncode([for (final o in orders) o.toJson()]));
    p.setString('$k.customer', jsonEncode(customer.toJson()));
    p.setDouble('$k.bonus', bonusBalance.toDouble());
    if (themeChoice != null) p.setString('$k.theme', themeChoice!.name);
    if (language != null) p.setString('$k.lang', language!);
  }

  void _restore() {
    final p = _prefs!;
    final k = storageKey;
    try {
      cart.addAll([for (final j in jsonDecode(p.getString('$k.cart') ?? '[]') as List) CartLine.fromJson(j)]);
      favorites.addAll(p.getStringList('$k.favorites') ?? const []);
      orders.addAll([for (final j in jsonDecode(p.getString('$k.orders') ?? '[]') as List) Order.fromJson(j)]);
      final c = p.getString('$k.customer');
      if (c != null) customer = Customer.fromJson(jsonDecode(c) as Map<String, dynamic>);
      // Приветственные бонусы, чтобы бонусную программу было видно сразу.
      bonusBalance = p.getDouble('$k.bonus') ?? 300;
      themeChoice = ThemeMode.values.asNameMap()[p.getString('$k.theme')];
      language = p.getString('$k.lang');
    } catch (_) {
      // Повреждённые данные — начинаем с чистого листа.
      cart.clear();
      orders.clear();
    }
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);
}
