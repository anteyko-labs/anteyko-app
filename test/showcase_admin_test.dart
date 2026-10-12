import 'dart:convert';

import 'package:app/admin/admin_app.dart';
import 'package:app/brand/brand_config.dart';
import 'package:app/core/models.dart';
import 'package:app/showcase/demos.dart';
import 'package:app/showcase/showcase_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/ui/motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_admin_api.dart';

void main() {
  ambientAnimations = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('каталог каждого демо парсится и ссылки внутри согласованы', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final ids = <String>{};
    for (final d in demos) {
      expect(ids.add(d.brand.id), isTrue, reason: 'id демо должны быть уникальны');
      final c = Catalog.fromJson(jsonDecode(await rootBundle.loadString(d.brand.catalogAsset)));
      expect(c.products, isNotEmpty, reason: d.title);
      for (final p in c.products) {
        expect(c.category(p.categoryId), isNotNull, reason: '${d.title}: ${p.title}');
      }
      for (final b in c.banners) {
        if (b.categoryId != null) expect(c.category(b.categoryId), isNotNull, reason: '${d.title}: ${b.title}');
      }
    }
  });

  testWidgets('витрина: открыть демо и вернуться', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ShowcaseApp());
    expect(find.text('Мобильное приложение для'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Кафе и доставка еды'), 300);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(find.text('Кафе и доставка еды')), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кафе и доставка еды'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(brand.id, 'demo-cafe');
    expect(find.text('Brick Pizza'), findsWidgets);

    await tester.tap(find.byTooltip('Все демо'));
    await tester.pumpAndSettle();
    expect(find.text('Мобильное приложение для'), findsOneWidget);
  });

  testWidgets('админка: вход, заказы, смена статуса', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeAdminApi(orders: sampleOrders());

    await tester.pumpWidget(AdminApp(api: api));
    await tester.enterText(find.byType(TextField).at(0), 'owner@shop.kg');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Неверный email или пароль'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Заказы').first);
    await tester.pumpAndSettle();
    expect(find.text('№42 · Айгерим'), findsOneWidget);

    await tester.tap(find.text('№42 · Айгерим'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Подтверждён'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('order 42 confirmed'));
  });

  testWidgets('админка: чужой пользователь не проходит', (tester) async {
    final api = FakeAdminApi(admin: false, signedInAs: 'x@x.com');
    await tester.pumpWidget(AdminApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Нет доступа'), findsOneWidget);
  });

  testWidgets('админка: создать товар', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeAdminApi(
      signedInAs: 'owner@shop.kg',
      tables: {
        'categories': [
          {'id': 'clothes', 'title': 'Одежда', 'icon': 'clothes', 'color': '#5B6CFF', 'sort': 0},
        ],
        'products': [],
        'banners': [],
      },
    );
    await tester.pumpWidget(AdminApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Товары').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Товар'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Название *'), 'Кепка');
    await tester.enterText(find.widgetWithText(TextFormField, 'Цена'), '1 200');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(api.calls, ['insert products']);
    final p = api.tables['products']!.single;
    expect(p['title'], 'Кепка');
    expect(p['price'], 1200);
    expect(p['category_id'], 'clothes');
    expect(find.text('Кепка'), findsOneWidget);
  });
}
