import 'package:app/core/app_state.dart';
import 'package:app/core/backend.dart';
import 'package:app/core/models.dart';
import 'package:app/core/order_service.dart';
import 'package:app/main.dart';
import 'package:app/ui/motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopSubmitter implements OrderSubmitter {
  @override
  Future<String?> submit(Order order) async => null;
}

void main() {
  ambientAnimations = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppState makeState() => AppState(backend: AssetBackend('assets/catalog.json', submitter: _NoopSubmitter()));

  test('каталог из assets парсится, корзина считает сумму', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final state = makeState();
    await state.init();
    final catalog = state.catalog!;
    expect(catalog.categories, isNotEmpty);
    expect(catalog.products, isNotEmpty);

    final p = catalog.products.firstWhere((p) => p.price != null);
    state.addToCart(p.id, options: {'Размер': 'M'});
    state.addToCart(p.id, options: {'Размер': 'M'});
    state.addToCart(p.id, options: {'Размер': 'L'});
    expect(state.cart.length, 2);
    expect(state.cartCount, 3);
    expect(state.subtotal, p.price! * 3);

    final order = await state.placeOrder(
      customer: const Customer(name: 'Тест', phone: '+996'),
      isDelivery: false,
      payment: 'cash',
      comment: '',
    );
    expect(order.total, p.price! * 3);
    expect(state.cart, isEmpty);
    expect(state.orders.first.id, order.id);
  });

  testWidgets('приложение запускается и показывает главную', (tester) async {
    final state = makeState();
    await tester.runAsync(state.init);
    await tester.pumpWidget(StoreApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsWidgets);
    expect(find.text('Каталог'), findsWidgets);
  });
}
