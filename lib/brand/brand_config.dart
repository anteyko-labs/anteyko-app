import 'package:flutter/material.dart';

/// ============================================================
///  БРЕНД КЛИЕНТА — единственный файл, который нужно менять
///  под нового заказчика (плюс assets/catalog.json и иконки).
/// ============================================================
/// true — приложение-витрина студии: на входе выбор демо (lib/showcase/).
/// false — сборка для клиента: сразу магазин с брендом [defaultBrand].
const showcaseMode = true;

/// Текущий бренд. В сборке клиента это всегда [defaultBrand];
/// в режиме витрины меняется при открытии демо.
BrandConfig get brand => _current;
BrandConfig _current = defaultBrand;
void setBrand(BrandConfig b) => _current = b;

const defaultBrand = BrandConfig(
  id: 'store',
  appName: 'Store',
  tagline: 'Всё нужное — в одном приложении',
  locale: 'ru',

  // Логотип: путь к картинке в assets/ или null — тогда текстовый логотип.
  logoAsset: null,

  // Цвета: вся палитра (кнопки, чипы, фоны) строится от primaryColor.
  primaryColor: Color(0xFF2F5BEA),
  saleColor: Color(0xFFE5484D),
  themeMode: ThemeMode.system,
  cornerRadius: 16,
  fontFamily: 'Manrope',

  currency: CurrencyFormat(symbol: 'сом', symbolAfter: true, decimals: 0),

  // Откуда брать каталог. Без Supabase — локальный JSON.
  catalogAsset: 'assets/catalog.json',

  // Supabase: каталог из базы, заказы в базу, веб-админка на /#/admin.
  // Supabase → Project Settings → API: Project URL и publishable (anon) key.
  // null — работа без сервера (каталог из JSON, заказы только в мессенджер).
  supabaseUrl: null,
  supabaseKey: null,

  features: Features(
    cart: true, // false → режим витрины: без корзины, кнопка «Связаться»
    favorites: true,
    search: true,
    banners: true,
    orderHistory: true,
    showPrices: true, // false → «Цена по запросу»
  ),

  checkout: CheckoutConfig(
    delivery: true,
    pickup: true,
    deliveryFee: 200,
    freeDeliveryFrom: 5000,
    minOrder: 0,
    paymentMethods: [PaymentMethod.cash, PaymentMethod.card, PaymentMethod.transfer],
    // Дополнительно продублировать заказ в мессенджер: whatsapp / telegram / email / none.
    // С Supabase заказ в любом случае попадает в админку; обычно тогда ставят none.
    orderChannel: OrderChannel.whatsapp,
  ),

  contacts: Contacts(
    phone: '+996 555 000 000',
    whatsapp: '996555000000',
    telegram: 'store_support',
    instagram: 'store',
    email: 'hello@store.example',
    address: 'г. Бишкек, ул. Примерная, 1',
    mapUrl: 'https://maps.google.com/?q=Bishkek',
    workHours: 'Ежедневно 10:00–20:00',
  ),

  about:
      'Мы продаём качественные товары по честным ценам и доставляем по всему городу. '
      'Замените этот текст описанием компании клиента.',
);

// ------------------------------------------------------------------
//  Типы конфигурации. Менять не нужно.
// ------------------------------------------------------------------

class BrandConfig {
  /// Короткий код бренда: им помечаются сохранённые данные (корзина, избранное).
  final String id;
  final String appName;
  final String tagline;
  final String locale;
  final String? logoAsset;
  final Color primaryColor;
  final Color saleColor;
  final ThemeMode themeMode;
  final double cornerRadius;
  final String? fontFamily;

  /// Шрифт заголовков (если отличается от основного).
  final String? headingFont;

  /// Вариант интерфейса: раскладка главной, вид карточек, сценарий покупки.
  final UiStyle style;
  final CurrencyFormat currency;
  final String catalogAsset;
  final String? supabaseUrl;
  final String? supabaseKey;
  final Features features;
  final CheckoutConfig checkout;
  final Contacts contacts;
  final String about;

  /// Текст кнопки на товаре, когда корзины нет (например, «Записаться»).
  final String? contactLabel;

  bool get hasBackend => supabaseUrl != null && supabaseKey != null;

  const BrandConfig({
    required this.id,
    required this.appName,
    required this.tagline,
    this.locale = 'ru',
    this.logoAsset,
    required this.primaryColor,
    this.saleColor = const Color(0xFFE5484D),
    this.themeMode = ThemeMode.system,
    this.cornerRadius = 16,
    this.fontFamily,
    this.headingFont,
    this.style = UiStyle.shop,
    this.currency = const CurrencyFormat(symbol: 'сом'),
    required this.catalogAsset,
    this.supabaseUrl,
    this.supabaseKey,
    this.features = const Features(),
    this.checkout = const CheckoutConfig(),
    required this.contacts,
    required this.about,
    this.contactLabel,
  });
}

class Features {
  final bool cart;
  final bool favorites;
  final bool search;
  final bool banners;
  final bool orderHistory;
  final bool showPrices;

  const Features({
    this.cart = true,
    this.favorites = true,
    this.search = true,
    this.banners = true,
    this.orderHistory = true,
    this.showPrices = true,
  });
}

class CurrencyFormat {
  final String symbol;
  final bool symbolAfter;
  final int decimals;
  final String thousandsSeparator;

  const CurrencyFormat({required this.symbol, this.symbolAfter = true, this.decimals = 0, this.thousandsSeparator = ' '});
}

/// Готовые интерфейсы. Данные и логика общие, отличаются экраны.
enum UiStyle {
  /// Магазин: баннеры, ленты, сетка карточек.
  shop,

  /// Кафе: меню с вкладками категорий, блюда списком, панель корзины.
  menu,

  /// Цветы/подарки: крупные карточки, мягкая типографика.
  boutique,

  /// Продукты: плотная сетка, +/− на карточке, прогресс до бесплатной доставки.
  grocery,

  /// Шоурум: минимализм, большие фото в одну колонку, заявка.
  showroom,

  /// Услуги: список с длительностью, онлайн-запись (мастер, дата, время).
  services,
}

enum PaymentMethod { cash, card, transfer }

enum OrderChannel { whatsapp, telegram, email, none }

class CheckoutConfig {
  final bool delivery;
  final bool pickup;
  final num deliveryFee;
  final num? freeDeliveryFrom;
  final num minOrder;
  final List<PaymentMethod> paymentMethods;
  final OrderChannel orderChannel;

  const CheckoutConfig({
    this.delivery = true,
    this.pickup = true,
    this.deliveryFee = 0,
    this.freeDeliveryFrom,
    this.minOrder = 0,
    this.paymentMethods = const [PaymentMethod.cash],
    this.orderChannel = OrderChannel.none,
  });
}

class Contacts {
  final String? phone;
  final String? whatsapp;
  final String? telegram;
  final String? instagram;
  final String? email;
  final String? address;
  final String? mapUrl;
  final String? workHours;

  const Contacts({
    this.phone,
    this.whatsapp,
    this.telegram,
    this.instagram,
    this.email,
    this.address,
    this.mapUrl,
    this.workHours,
  });
}
