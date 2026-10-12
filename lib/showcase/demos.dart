import 'package:flutter/material.dart';

import '../brand/brand_config.dart';
import '../core/features.dart';

/// Студия, от имени которой показывается витрина.
const studio = (
  name: 'Anteyko',
  tagline: 'Мобильные приложения для бизнеса',
  telegram: 'anteyko_labs',
  phone: '+996 709 927 895',
  site: 'https://anteyko.com',
);

/// Один тип приложения в витрине: бренд демо + описание для карточки.
class DemoTemplate {
  final BrandConfig brand;
  final String title;
  final String pitch;
  final IconData icon;
  final List<String> highlights;

  const DemoTemplate({
    required this.brand,
    required this.title,
    required this.pitch,
    required this.icon,
    required this.highlights,
  });
}

const _contacts = Contacts(
  phone: '+996 709 927 895',
  telegram: 'anteyko_labs',
  instagram: 'anteyko',
  address: 'Бишкек, ул. Юнусалиева, 80',
  mapUrl: 'https://maps.google.com/?q=Bishkek',
  workHours: 'Ежедневно 09:00–21:00',
);

const demos = <DemoTemplate>[
  DemoTemplate(
    title: 'Интернет-магазин',
    pitch: 'Одежда, электроника, товары для дома — каталог, корзина и доставка.',
    icon: Icons.shopping_bag_outlined,
    highlights: ['Баннеры', 'Размеры и цвета', 'Скидки', 'Доставка'],
    brand: BrandConfig(
      id: 'demo-shop',
      style: UiStyle.shop,
      fontFamily: 'Manrope',
      appName: 'Moda',
      tagline: 'Одежда и всё для жизни',
      primaryColor: Color(0xFF2F5BEA),
      catalogAsset: 'assets/demos/shop.json',
      contacts: _contacts,
      checkout: CheckoutConfig(
        deliveryFee: 200,
        freeDeliveryFrom: 5000,
        paymentMethods: [PaymentMethod.cash, PaymentMethod.card, PaymentMethod.transfer],
      ),
      about: 'Демо интернет-магазина от Anteyko. Ваш бренд, ваши товары, ваша доставка.',
    ),
  ),
  DemoTemplate(
    title: 'Кафе и доставка еды',
    pitch: 'Меню с добавками и размерами, быстрый заказ на доставку или самовывоз.',
    icon: Icons.restaurant_menu,
    highlights: ['Тёмная тема', 'Меню с вкладками', 'Добавки', 'Панель корзины'],
    brand: BrandConfig(
      id: 'demo-cafe',
      style: UiStyle.menu,
      fontFamily: 'Rubik',
      themeMode: ThemeMode.dark,
      appName: 'Brick Pizza',
      tagline: 'Горячо и быстро — доставка за 40 минут',
      primaryColor: Color(0xFFFF6B2C),
      cornerRadius: 20,
      catalogAsset: 'assets/demos/cafe.json',
      contacts: _contacts,
      checkout: CheckoutConfig(
        deliveryFee: 150,
        freeDeliveryFrom: 1500,
        minOrder: 500,
        paymentMethods: [PaymentMethod.cash, PaymentMethod.card],
      ),
      about: 'Демо приложения для кафе и ресторанов от Anteyko.',
    ),
  ),
  DemoTemplate(
    title: 'Цветы и подарки',
    pitch: 'Букеты с доставкой к нужному времени, открытки и дополнения.',
    icon: Icons.local_florist_outlined,
    highlights: ['Нежный стиль', 'Крупные фото', 'Поштучно', 'Доставка'],
    brand: BrandConfig(
      id: 'demo-flowers',
      style: UiStyle.boutique,
      fontFamily: 'Manrope',
      headingFont: 'CormorantGaramond',
      themeMode: ThemeMode.light,
      appName: 'Flora',
      tagline: 'Цветы, которые говорят за вас',
      primaryColor: Color(0xFFC81E4A),
      cornerRadius: 22,
      catalogAsset: 'assets/demos/flowers.json',
      contacts: _contacts,
      checkout: CheckoutConfig(
        deliveryFee: 300,
        freeDeliveryFrom: 5000,
        paymentMethods: [PaymentMethod.card, PaymentMethod.transfer],
      ),
      about: 'Демо цветочного магазина от Anteyko.',
    ),
  ),
  DemoTemplate(
    title: 'Продукты',
    pitch: 'Супермаркет или лавка: цены за килограмм, быстрая корзина, повтор заказа.',
    icon: Icons.local_grocery_store_outlined,
    highlights: ['Цена за кг', '+/− на карточке', 'Полки товаров', 'Бесплатная доставка'],
    brand: BrandConfig(
      id: 'demo-grocery',
      style: UiStyle.grocery,
      fontFamily: 'Nunito',
      themeMode: ThemeMode.light,
      appName: 'Fresh',
      tagline: 'Свежие продукты за 30 минут',
      primaryColor: Color(0xFF16A34A),
      cornerRadius: 14,
      catalogAsset: 'assets/demos/grocery.json',
      contacts: _contacts,
      checkout: CheckoutConfig(
        deliveryFee: 100,
        freeDeliveryFrom: 2000,
        minOrder: 700,
        pickup: false,
        paymentMethods: [PaymentMethod.cash, PaymentMethod.card],
      ),
      about: 'Демо приложения для продуктового магазина от Anteyko.',
    ),
  ),
  DemoTemplate(
    title: 'Мебель и шоурум',
    pitch: 'Каталог-витрина без корзины: характеристики, варианты и заявка менеджеру.',
    icon: Icons.chair_outlined,
    highlights: ['Минимализм', 'Большие фото', 'Цена по запросу', 'Заявка на замер'],
    brand: BrandConfig(
      id: 'demo-furniture',
      style: UiStyle.showroom,
      fontFamily: 'Montserrat',
      themeMode: ThemeMode.light,
      appName: 'Nord Home',
      tagline: 'Мебель, сделанная в Бишкеке',
      primaryColor: Color(0xFF7C6A55),
      cornerRadius: 2,
      catalogAsset: 'assets/demos/furniture.json',
      contacts: _contacts,
      features: Features(cart: false, orderHistory: false),
      contactLabel: 'Оставить заявку',
      about: 'Демо каталога-витрины от Anteyko: для мебели, стройматериалов, B2B.',
    ),
  ),
  DemoTemplate(
    title: 'Салон красоты',
    pitch: 'Каталог услуг с мастерами и длительностью, запись в один клик.',
    icon: Icons.content_cut,
    highlights: ['Онлайн-запись', 'Выбор мастера', 'Дата и время', 'Акции'],
    brand: BrandConfig(
      id: 'demo-beauty',
      style: UiStyle.services,
      fontFamily: 'Manrope',
      headingFont: 'PlayfairDisplay',
      themeMode: ThemeMode.light,
      appName: 'Lumière',
      tagline: 'Студия красоты',
      primaryColor: Color(0xFFB0708A),
      cornerRadius: 24,
      catalogAsset: 'assets/demos/beauty.json',
      contacts: _contacts,
      features: Features(cart: false, orderHistory: false),
      contactLabel: 'Записаться',
      about: 'Демо приложения для салонов и сервисов по записи от Anteyko.',
    ),
  ),
];

/// Цвет тарифа в витрине и админке.
Color planColor(Plan p) => switch (p) {
  Plan.start => const Color(0xFF64748B),
  Plan.business => const Color(0xFF4F6BFF),
  Plan.premium => const Color(0xFFE0A100),
};

/// Цены тарифов для раздела «Тарифы» в витрине. ⚠️ Пример — замените на свои.
const planPrices = <Plan, (String price, String note)>{
  Plan.start: (r'$490', 'разработка · запуск за 7 дней'),
  Plan.business: (r'$990', 'разработка · запуск за 2 недели'),
  Plan.premium: (r'$1 790', 'разработка · запуск за 3–4 недели'),
};

/// Ключевые пункты для карточек тарифов (полный список — в таблице сравнения).
const planHighlights = <Plan, List<String>>{
  Plan.start: [
    'Каталог, поиск, карточки товаров',
    'Заявка в WhatsApp / Telegram',
    'Ваш бренд и цвета',
    'До 30 товаров, 1 баннер',
  ],
  Plan.business: [
    'Всё из «Старт»',
    'Корзина, доставка, время доставки',
    'Онлайн-запись для услуг',
    'Избранное, фильтры, история заказов',
    'Админка: заказы и статусы',
    'До 500 товаров',
  ],
  Plan.premium: [
    'Всё из «Бизнес»',
    'Бонусная программа и промокоды',
    'Отзывы и рейтинг, сторис',
    'Тёмная тема и английский язык',
    'Анимации и «стекло» iOS',
    'Аналитика продаж, без лимитов',
  ],
};
