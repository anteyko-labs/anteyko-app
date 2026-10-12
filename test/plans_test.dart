import 'package:app/admin/admin_app.dart';
import 'package:app/admin/local_admin_api.dart';
import 'package:app/brand/brand_config.dart';
import 'package:app/core/app_state.dart';
import 'package:app/core/backend.dart';
import 'package:app/core/features.dart';
import 'package:app/core/local_store.dart';
import 'package:app/core/models.dart';
import 'package:app/core/order_service.dart';
import 'package:app/showcase/demos.dart';
import 'package:app/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_admin_api.dart';

class _Noop implements OrderSubmitter {
  @override
  Future<String?> submit(Order order) async => null;
}

void main() {
  ambientAnimations = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setBrand(defaultBrand);
  });

  group('тарифы и функции', () {
    test('тариф включает свои функции и все функции младших тарифов', () {
      const start = AppSettings(plan: Plan.start);
      const business = AppSettings(plan: Plan.business);
      const premium = AppSettings(plan: Plan.premium);
      expect(isEnabledIn(start, Feature.search), isTrue);
      expect(isEnabledIn(start, Feature.cart), isFalse);
      expect(isEnabledIn(business, Feature.cart), isTrue);
      expect(isEnabledIn(business, Feature.loyalty), isFalse);
      for (final f in Feature.values.where((f) => brandBlocks(f) == null)) {
        expect(isEnabledIn(premium, f), isTrue, reason: f.name);
      }
    });

    test('ручной переключатель сильнее тарифа', () {
      const s = AppSettings(plan: Plan.start, overrides: {Feature.reviews: true, Feature.search: false});
      expect(isEnabledIn(s, Feature.reviews), isTrue);
      expect(isEnabledIn(s, Feature.search), isFalse);
    });

    test('бонусы и промокоды не работают без корзины', () {
      const s = AppSettings(plan: Plan.premium, overrides: {Feature.cart: false});
      expect(isEnabledIn(s, Feature.loyalty), isFalse);
      expect(isEnabledIn(s, Feature.promoCodes), isFalse);
      expect(isEnabledIn(s, Feature.reviews), isTrue);
    });

    test('тип бизнеса ограничивает функции: шоуруму корзина не нужна, запись — только для услуг', () {
      setBrand(demos.firstWhere((d) => d.brand.style == UiStyle.showroom).brand);
      expect(isEnabledIn(const AppSettings(), Feature.cart), isFalse);
      expect(isEnabledIn(const AppSettings(), Feature.booking), isFalse);
      setBrand(demos.firstWhere((d) => d.brand.style == UiStyle.services).brand);
      expect(isEnabledIn(const AppSettings(), Feature.booking), isTrue, reason: 'у салона нет корзины, но запись — есть');
      expect(isEnabledIn(const AppSettings(), Feature.cart), isFalse);
    });

    test('настройки переживают сохранение', () {
      const s = AppSettings(plan: Plan.business, overrides: {Feature.reviews: true}, loyaltyPercent: 7);
      final back = AppSettings.fromJson(s.toJson());
      expect(back.plan, Plan.business);
      expect(back.overrides, {Feature.reviews: true});
      expect(back.loyaltyPercent, 7);
    });
  });

  test('промокод и бонусы в заказе', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final state = AppState(backend: AssetBackend('assets/catalog.json', submitter: _Noop()));
    await state.init();
    final p = state.catalog!.products.firstWhere((p) => p.price == 890);
    state.addToCart(p.id, quantity: 4); // 3 560
    expect(state.promoDiscount('welcome10'), 356);
    expect(state.promoDiscount('SALE500'), 500);
    expect(state.promoDiscount('NOPE'), 0);
    final bonusBefore = state.bonusBalance; // приветственные 300
    final order = await state.placeOrder(
      customer: const Customer(name: 'Тест', phone: '1'),
      isDelivery: false,
      payment: 'cash',
      comment: '',
      promoCode: 'welcome10',
      bonusToSpend: 10000,
    );
    expect(order.discount, 356);
    expect(order.bonusSpent, bonusBefore); // списали всё, что было (меньше 30% заказа)
    expect(order.total, 3560 - 356 - bonusBefore);
    expect(state.bonusBalance, order.bonusEarned);
    expect(order.bonusEarned, ((3560 - 356 - bonusBefore) * 5 / 100).floor());
  });

  test('правка в админке сразу видна в приложении (общая база)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final store = LocalStore(id: 'test', seedAsset: 'assets/catalog.json');
    final state = AppState(backend: store);
    await state.init();
    state.activate(); // как будто приложение на экране
    final before = state.catalog!.products.length;
    expect(store.orders, isNotEmpty, reason: 'демо-заказы для аналитики');

    final admin = LocalAdminApi(store);
    await admin.insert('products', {
      'title': 'Новинка из админки',
      'category_id': 'clothes',
      'price': 100,
      'active': true,
      'sort': 0,
    });
    await admin.saveSettings(const AppSettings(plan: Plan.start));
    await Future<void>.delayed(Duration.zero);
    await state.reload();
    expect(state.catalog!.products.length, before + 1);
    expect(state.catalog!.products.any((p) => p.title == 'Новинка из админки'), isTrue);
    expect(state.settings.plan, Plan.start);
    expect(has(Feature.cart), isFalse);

    // Заказ из приложения появляется в админке со статусом «новый».
    await admin.saveSettings(const AppSettings(plan: Plan.business));
    await state.reload();
    state.addToCart(state.catalog!.products.firstWhere((p) => p.price != null).id);
    final order = await state.placeOrder(
      customer: const Customer(name: 'А', phone: '1'),
      isDelivery: false,
      payment: 'cash',
      comment: '',
    );
    final orders = await admin.orders(status: 'new');
    expect(orders.any((o) => o['id'] == order.id), isTrue);
    await admin.updateOrder(order.id, {'status': 'done'});
    await state.reload();
    expect(state.statuses[order.id], 'done');
  });

  testWidgets('админка: тариф одной кнопкой и ручной переключатель', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeAdminApi(signedInAs: 'owner@shop.kg')..settings = const AppSettings(plan: Plan.premium);
    await tester.pumpWidget(AdminApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тариф').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Старт').first);
    await tester.pumpAndSettle();
    expect(api.settings.plan, Plan.start);
    // На «Старте» нет корзины — раздел «Заказы» пропал из меню.
    expect(find.text('Заказы'), findsNothing);

    // Включаем «Отзывы» вручную поверх тарифа.
    final tile = find.ancestor(of: find.text('Отзывы и рейтинг'), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(api.settings.overrides[Feature.reviews], isTrue);
    expect(find.text('вручную'), findsOneWidget);
    expect(find.text('Отзывы'), findsWidgets, reason: 'раздел модерации появился');

    await tester.tap(find.text('Сбросить к тарифу'));
    await tester.pumpAndSettle();
    expect(api.settings.overrides, isEmpty);
  });

  testWidgets('админка: лимит товаров на тарифе «Старт»', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeAdminApi(
      signedInAs: 'owner@shop.kg',
      tables: {
        'categories': [],
        'products': [
          for (var i = 0; i < 30; i++)
            {'id': 'p$i', 'title': 'Товар $i', 'price': 100, 'images': [], 'in_stock': true, 'active': true, 'sort': i},
        ],
        'banners': [],
      },
    )..settings = const AppSettings(plan: Plan.start);
    await tester.pumpWidget(AdminApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Товары').first);
    await tester.pumpAndSettle();
    expect(find.text('30 / 30'), findsOneWidget);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Товар'));
    await tester.pumpAndSettle();
    expect(find.text('Лимит тарифа: 30 товаров'), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('insert')), isEmpty);
  });
}
