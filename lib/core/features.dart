import 'package:flutter/material.dart';

import '../brand/brand_config.dart';

/// Тарифы. Порядок важен: каждый следующий включает всё из предыдущего.
enum Plan { start, business, premium }

class PlanInfo {
  final String title;
  final String tagline;
  final IconData icon;

  /// Лимиты админки. null — без ограничений.
  final int? productLimit;
  final int? bannerLimit;

  const PlanInfo({required this.title, required this.tagline, required this.icon, this.productLimit, this.bannerLimit});
}

const planInfo = <Plan, PlanInfo>{
  Plan.start: PlanInfo(
    title: 'Старт',
    tagline: 'Каталог и заявки — быстрый запуск',
    icon: Icons.rocket_launch_outlined,
    productLimit: 30,
    bannerLimit: 1,
  ),
  Plan.business: PlanInfo(
    title: 'Бизнес',
    tagline: 'Полноценные продажи: корзина, доставка, заказы',
    icon: Icons.storefront_outlined,
    productLimit: 500,
    bannerLimit: 5,
  ),
  Plan.premium: PlanInfo(
    title: 'Премиум',
    tagline: 'Всё для роста: бонусы, промокоды, отзывы, аналитика',
    icon: Icons.workspace_premium_outlined,
  ),
};

enum FeatureGroup { sales, marketing, clients, design, admin }

const featureGroupTitle = {
  FeatureGroup.sales: 'Продажи',
  FeatureGroup.marketing: 'Маркетинг',
  FeatureGroup.clients: 'Клиенты',
  FeatureGroup.design: 'Дизайн и удобство',
  FeatureGroup.admin: 'Админ-панель',
};

/// Функции, которые включаются тарифом или вручную в админке.
enum Feature {
  search,
  banners,
  cart,
  favorites,
  filters,
  orderHistory,
  deliverySlots,
  booking,
  promoCodes,
  loyalty,
  reviews,
  stories,
  themeSwitch,
  languages,
  premiumMotion,
  analytics,
}

class FeatureInfo {
  final String title;
  final String description;
  final IconData icon;
  final FeatureGroup group;

  /// С какого тарифа функция включена по умолчанию.
  final Plan plan;
  const FeatureInfo(this.title, this.description, this.icon, this.group, this.plan);
}

const featureInfo = <Feature, FeatureInfo>{
  Feature.search: FeatureInfo('Поиск', 'Поиск по названию, описанию и категориям', Icons.search, FeatureGroup.sales, Plan.start),
  Feature.cart: FeatureInfo(
    'Корзина и оформление',
    'Заказ в приложении: доставка или самовывоз, способ оплаты. Без неё — заявка в WhatsApp',
    Icons.shopping_bag_outlined,
    FeatureGroup.sales,
    Plan.business,
  ),
  Feature.deliverySlots: FeatureInfo(
    'Время доставки',
    'Клиент выбирает удобный интервал доставки',
    Icons.schedule,
    FeatureGroup.sales,
    Plan.business,
  ),
  Feature.booking: FeatureInfo(
    'Онлайн-запись',
    'Выбор мастера, даты и времени (для услуг)',
    Icons.event_available,
    FeatureGroup.sales,
    Plan.business,
  ),
  Feature.filters: FeatureInfo(
    'Сортировка и фильтры',
    'По цене, наличию и скидкам',
    Icons.tune,
    FeatureGroup.sales,
    Plan.business,
  ),
  Feature.banners: FeatureInfo(
    'Баннеры',
    'Акции на главной с автопрокруткой',
    Icons.view_carousel_outlined,
    FeatureGroup.marketing,
    Plan.business,
  ),
  Feature.promoCodes: FeatureInfo(
    'Промокоды',
    'Скидки по коду: процент или сумма, минимальный заказ',
    Icons.confirmation_number_outlined,
    FeatureGroup.marketing,
    Plan.premium,
  ),
  Feature.stories: FeatureInfo(
    'Сторис',
    'Истории на главной, как в Instagram',
    Icons.amp_stories_outlined,
    FeatureGroup.marketing,
    Plan.premium,
  ),
  Feature.favorites: FeatureInfo(
    'Избранное',
    'Клиент сохраняет понравившиеся товары',
    Icons.favorite_border,
    FeatureGroup.clients,
    Plan.business,
  ),
  Feature.orderHistory: FeatureInfo(
    'История и повтор заказов',
    'Статусы заказов и повтор в один тап',
    Icons.receipt_long_outlined,
    FeatureGroup.clients,
    Plan.business,
  ),
  Feature.loyalty: FeatureInfo(
    'Бонусная программа',
    'Кэшбэк бонусами и оплата ими следующих заказов',
    Icons.loyalty_outlined,
    FeatureGroup.clients,
    Plan.premium,
  ),
  Feature.reviews: FeatureInfo(
    'Отзывы и рейтинг',
    'Звёзды на карточках, отзывы с модерацией',
    Icons.star_outline,
    FeatureGroup.clients,
    Plan.premium,
  ),
  Feature.premiumMotion: FeatureInfo(
    'Анимации и «стекло»',
    'Живые переходы, полёт в корзину, конфетти, размытые панели',
    Icons.auto_awesome,
    FeatureGroup.design,
    Plan.premium,
  ),
  Feature.themeSwitch: FeatureInfo(
    'Тёмная тема',
    'Клиент сам выбирает светлую или тёмную тему',
    Icons.dark_mode_outlined,
    FeatureGroup.design,
    Plan.premium,
  ),
  Feature.languages: FeatureInfo(
    'Русский / English',
    'Переключение языка интерфейса',
    Icons.translate,
    FeatureGroup.design,
    Plan.premium,
  ),
  Feature.analytics: FeatureInfo(
    'Аналитика продаж',
    'Выручка, средний чек, график и топ товаров в админке',
    Icons.insights_outlined,
    FeatureGroup.admin,
    Plan.premium,
  ),
};

class PromoCode {
  final String code;
  final int percent;
  final num amount;
  final num minSum;
  final bool active;

  const PromoCode({required this.code, this.percent = 0, this.amount = 0, this.minSum = 0, this.active = true});

  num discountFor(num subtotal) {
    if (!active || subtotal < minSum) return 0;
    final d = percent > 0 ? subtotal * percent / 100 : amount;
    return d.clamp(0, subtotal).round();
  }

  String get label => percent > 0 ? '−$percent%' : '−${amount.round()}';

  Map<String, dynamic> toJson() => {'code': code, 'percent': percent, 'amount': amount, 'minSum': minSum, 'active': active};

  factory PromoCode.fromJson(Map<String, dynamic> j) => PromoCode(
    code: (j['code'] as String).toUpperCase(),
    percent: (j['percent'] as num? ?? 0).toInt(),
    amount: j['amount'] as num? ?? 0,
    minSum: j['minSum'] as num? ?? 0,
    active: j['active'] as bool? ?? true,
  );
}

/// Настройки приложения из админки: тариф, ручные переключатели, маркетинг.
class AppSettings {
  final Plan plan;
  final Map<Feature, bool> overrides;
  final List<PromoCode> promoCodes;
  final int loyaltyPercent;
  final int loyaltyMaxSpendPercent;

  const AppSettings({
    this.plan = Plan.premium,
    this.overrides = const {},
    this.promoCodes = const [],
    this.loyaltyPercent = 5,
    this.loyaltyMaxSpendPercent = 30,
  });

  bool includedInPlan(Feature f) => featureInfo[f]!.plan.index <= plan.index;

  bool isOn(Feature f) => overrides[f] ?? includedInPlan(f);

  PlanInfo get info => planInfo[plan]!;

  PromoCode? promo(String code) {
    final c = code.trim().toUpperCase();
    return promoCodes.where((p) => p.code == c && p.active).firstOrNull;
  }

  AppSettings copyWith({
    Plan? plan,
    Map<Feature, bool>? overrides,
    List<PromoCode>? promoCodes,
    int? loyaltyPercent,
    int? loyaltyMaxSpendPercent,
  }) => AppSettings(
    plan: plan ?? this.plan,
    overrides: overrides ?? this.overrides,
    promoCodes: promoCodes ?? this.promoCodes,
    loyaltyPercent: loyaltyPercent ?? this.loyaltyPercent,
    loyaltyMaxSpendPercent: loyaltyMaxSpendPercent ?? this.loyaltyMaxSpendPercent,
  );

  Map<String, dynamic> toJson() => {
    'plan': plan.name,
    'overrides': {for (final e in overrides.entries) e.key.name: e.value},
    'promoCodes': [for (final p in promoCodes) p.toJson()],
    'loyaltyPercent': loyaltyPercent,
    'loyaltyMaxSpendPercent': loyaltyMaxSpendPercent,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    plan: Plan.values.asNameMap()[j['plan']] ?? Plan.premium,
    overrides: {
      for (final e in (j['overrides'] as Map? ?? {}).entries)
        ?Feature.values.asNameMap()[e.key]: e.value == true,
    },
    promoCodes: [for (final p in j['promoCodes'] as List? ?? []) PromoCode.fromJson(Map<String, dynamic>.from(p as Map))],
    loyaltyPercent: (j['loyaltyPercent'] as num? ?? 5).toInt(),
    loyaltyMaxSpendPercent: (j['loyaltyMaxSpendPercent'] as num? ?? 30).toInt(),
  );

  static const demoPromoCodes = [
    PromoCode(code: 'WELCOME10', percent: 10),
    PromoCode(code: 'SALE500', amount: 500, minSum: 3000),
  ];
}

/// Ограничения по типу бизнеса: например, шоуруму корзина не нужна,
/// а онлайн-запись имеет смысл только для услуг. Тариф их не обходит.
String? brandBlocks(Feature f) => switch (f) {
  Feature.cart ||
  Feature.deliverySlots ||
  Feature.promoCodes ||
  Feature.loyalty ||
  Feature.orderHistory when !brand.features.cart => 'Недоступно для этого типа приложения (без корзины)',
  Feature.booking when brand.style != UiStyle.services => 'Только для приложений услуг',
  Feature.favorites when !brand.features.favorites => 'Отключено в настройках бренда',
  Feature.search when !brand.features.search => 'Отключено в настройках бренда',
  Feature.banners when !brand.features.banners => 'Отключено в настройках бренда',
  _ => null,
};

// ---------------------------------------------------------------------------
//  Текущие настройки приложения (как и brand — одно активное приложение за раз).
// ---------------------------------------------------------------------------

AppSettings _settings = const AppSettings();
AppSettings get appSettings => _settings;
void setAppSettings(AppSettings s) => _settings = s;

/// Функции, которые работают только вместе с корзиной.
const featureRequires = <Feature, Feature>{
  Feature.deliverySlots: Feature.cart,
  Feature.promoCodes: Feature.cart,
  Feature.loyalty: Feature.cart,
  Feature.orderHistory: Feature.cart,
};

/// Включена ли функция сейчас: тариф/переключатель админа + ограничения бренда + зависимости.
bool has(Feature f) => isEnabledIn(_settings, f);

bool isEnabledIn(AppSettings s, Feature f) {
  if (!s.isOn(f) || brandBlocks(f) != null) return false;
  final dep = featureRequires[f];
  return dep == null || isEnabledIn(s, dep);
}
