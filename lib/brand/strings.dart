import 'brand_config.dart';

/// Тексты интерфейса. Язык выбирается в brand.locale.
/// Чтобы добавить язык — добавьте словарь в [_dictionaries].
class S {
  /// Язык интерфейса. Меняется на лету (функция «Русский / English»).
  static String lang = brand.locale;

  static Map<String, String> get _t => _dictionaries[lang] ?? _dictionaries['ru']!;

  static String get(String key) => _t[key] ?? _dictionaries['ru']![key] ?? key;

  static String get home => get('home');
  static String get catalog => get('catalog');
  static String get favorites => get('favorites');
  static String get cart => get('cart');
  static String get more => get('more');
  static String get search => get('search');
  static String get searchHint => get('searchHint');
  static String get categories => get('categories');
  static String get featured => get('featured');
  static String get sale => get('sale');
  static String get allProducts => get('allProducts');
  static String get seeAll => get('seeAll');
  static String get addToCart => get('addToCart');
  static String get inCart => get('inCart');
  static String get outOfStock => get('outOfStock');
  static String get priceOnRequest => get('priceOnRequest');
  static String get contactUs => get('contactUs');
  static String get description => get('description');
  static String get specs => get('specs');
  static String get quantity => get('quantity');
  static String get emptyCart => get('emptyCart');
  static String get emptyCartHint => get('emptyCartHint');
  static String get emptyFavorites => get('emptyFavorites');
  static String get emptyFavoritesHint => get('emptyFavoritesHint');
  static String get nothingFound => get('nothingFound');
  static String get subtotal => get('subtotal');
  static String get delivery => get('delivery');
  static String get pickup => get('pickup');
  static String get free => get('free');
  static String get total => get('total');
  static String get checkout => get('checkout');
  static String get placeOrder => get('placeOrder');
  static String get name => get('name');
  static String get phone => get('phone');
  static String get address => get('address');
  static String get comment => get('comment');
  static String get required => get('required');
  static String get payment => get('payment');
  static String get cash => get('cash');
  static String get card => get('card');
  static String get transfer => get('transfer');
  static String get orderPlaced => get('orderPlaced');
  static String get orderPlacedHint => get('orderPlacedHint');
  static String get toHome => get('toHome');
  static String get orders => get('orders');
  static String get noOrders => get('noOrders');
  static String get order => get('order');
  static String get contacts => get('contacts');
  static String get about => get('about');
  static String get workHours => get('workHours');
  static String get sortPopular => get('sortPopular');
  static String get sortPriceAsc => get('sortPriceAsc');
  static String get sortPriceDesc => get('sortPriceDesc');
  static String get sortName => get('sortName');
  static String get inStockOnly => get('inStockOnly');
  static String get onSale => get('onSale');
  static String get retry => get('retry');
  static String get loadError => get('loadError');
  static String get minOrder => get('minOrder');
  static String get freeDeliveryFrom => get('freeDeliveryFrom');
  static String get products => get('products');
  static String get repeatOrder => get('repeatOrder');
  static String get clear => get('clear');
  static String get pcs => get('pcs');
  static String get details => get('details');
  static String get promoCode => get('promoCode');
  static String get apply => get('apply');
  static String get promoApplied => get('promoApplied');
  static String get promoInvalid => get('promoInvalid');
  static String get discount => get('discount');
  static String get bonuses => get('bonuses');
  static String get payWithBonuses => get('payWithBonuses');
  static String get bonusBalance => get('bonusBalance');
  static String get cashback => get('cashback');
  static String get willEarn => get('willEarn');
  static String get deliveryTime => get('deliveryTime');
  static String get asap => get('asap');
  static String get reviews => get('reviews');
  static String get writeReview => get('writeReview');
  static String get yourRating => get('yourRating');
  static String get reviewText => get('reviewText');
  static String get send => get('send');
  static String get reviewThanks => get('reviewThanks');
  static String get noReviews => get('noReviews');
  static String get appearance => get('appearance');
  static String get themeSystem => get('themeSystem');
  static String get themeLight => get('themeLight');
  static String get themeDark => get('themeDark');
  static String get language => get('language');
  static String get settings => get('settings');
  static String status(String s) => get('status_$s');
}

const Map<String, Map<String, String>> _dictionaries = {
  'ru': {
    'home': 'Главная',
    'catalog': 'Каталог',
    'favorites': 'Избранное',
    'cart': 'Корзина',
    'more': 'Ещё',
    'search': 'Поиск',
    'searchHint': 'Найти товар',
    'categories': 'Категории',
    'featured': 'Популярное',
    'sale': 'Скидки',
    'allProducts': 'Все товары',
    'seeAll': 'Все',
    'addToCart': 'В корзину',
    'inCart': 'В корзине',
    'outOfStock': 'Нет в наличии',
    'priceOnRequest': 'Цена по запросу',
    'contactUs': 'Связаться',
    'description': 'Описание',
    'specs': 'Характеристики',
    'quantity': 'Количество',
    'emptyCart': 'Корзина пуста',
    'emptyCartHint': 'Добавьте товары из каталога',
    'emptyFavorites': 'Пока ничего нет',
    'emptyFavoritesHint': 'Нажмите ♡ на товаре, чтобы сохранить его',
    'nothingFound': 'Ничего не найдено',
    'subtotal': 'Товары',
    'delivery': 'Доставка',
    'pickup': 'Самовывоз',
    'free': 'Бесплатно',
    'total': 'Итого',
    'checkout': 'Оформление заказа',
    'placeOrder': 'Оформить заказ',
    'name': 'Имя',
    'phone': 'Телефон',
    'address': 'Адрес',
    'comment': 'Комментарий',
    'required': 'Заполните поле',
    'payment': 'Оплата',
    'cash': 'Наличными',
    'card': 'Картой',
    'transfer': 'Переводом',
    'orderPlaced': 'Заказ оформлен',
    'orderPlacedHint': 'Мы свяжемся с вами для подтверждения',
    'toHome': 'На главную',
    'orders': 'Мои заказы',
    'noOrders': 'Заказов пока нет',
    'order': 'Заказ',
    'contacts': 'Контакты',
    'about': 'О нас',
    'workHours': 'Часы работы',
    'sortPopular': 'По популярности',
    'sortPriceAsc': 'Сначала дешевле',
    'sortPriceDesc': 'Сначала дороже',
    'sortName': 'По названию',
    'inStockOnly': 'В наличии',
    'onSale': 'Со скидкой',
    'retry': 'Повторить',
    'loadError': 'Не удалось загрузить каталог',
    'minOrder': 'Минимальная сумма заказа',
    'freeDeliveryFrom': 'Бесплатная доставка от',
    'products': 'товаров',
    'repeatOrder': 'Повторить заказ',
    'clear': 'Очистить',
    'pcs': 'шт.',
    'details': 'Подробнее',
    'promoCode': 'Промокод',
    'apply': 'Применить',
    'promoApplied': 'Промокод применён',
    'promoInvalid': 'Промокод не найден или не подходит к сумме',
    'discount': 'Скидка',
    'bonuses': 'Бонусы',
    'payWithBonuses': 'Списать бонусы',
    'bonusBalance': 'Бонусный счёт',
    'cashback': 'кэшбэк бонусами с каждого заказа',
    'willEarn': 'Начислим бонусов',
    'deliveryTime': 'Время доставки',
    'asap': 'Как можно скорее',
    'reviews': 'Отзывы',
    'writeReview': 'Оставить отзыв',
    'yourRating': 'Ваша оценка',
    'reviewText': 'Что понравилось или нет?',
    'send': 'Отправить',
    'reviewThanks': 'Спасибо! Отзыв появится после проверки',
    'noReviews': 'Пока нет отзывов — будьте первым',
    'appearance': 'Оформление',
    'themeSystem': 'Как в системе',
    'themeLight': 'Светлая',
    'themeDark': 'Тёмная',
    'language': 'Язык',
    'settings': 'Настройки',
    'status_new': 'Новый',
    'status_confirmed': 'Подтверждён',
    'status_delivering': 'В доставке',
    'status_done': 'Выполнен',
    'status_cancelled': 'Отменён',
  },
  'en': {
    'home': 'Home',
    'catalog': 'Catalog',
    'favorites': 'Favorites',
    'cart': 'Cart',
    'more': 'More',
    'search': 'Search',
    'searchHint': 'Search products',
    'categories': 'Categories',
    'featured': 'Popular',
    'sale': 'On sale',
    'allProducts': 'All products',
    'seeAll': 'See all',
    'addToCart': 'Add to cart',
    'inCart': 'In cart',
    'outOfStock': 'Out of stock',
    'priceOnRequest': 'Price on request',
    'contactUs': 'Contact us',
    'description': 'Description',
    'specs': 'Specifications',
    'quantity': 'Quantity',
    'emptyCart': 'Your cart is empty',
    'emptyCartHint': 'Add something from the catalog',
    'emptyFavorites': 'Nothing here yet',
    'emptyFavoritesHint': 'Tap ♡ on a product to save it',
    'nothingFound': 'Nothing found',
    'subtotal': 'Items',
    'delivery': 'Delivery',
    'pickup': 'Pickup',
    'free': 'Free',
    'total': 'Total',
    'checkout': 'Checkout',
    'placeOrder': 'Place order',
    'name': 'Name',
    'phone': 'Phone',
    'address': 'Address',
    'comment': 'Comment',
    'required': 'Required',
    'payment': 'Payment',
    'cash': 'Cash',
    'card': 'Card',
    'transfer': 'Bank transfer',
    'orderPlaced': 'Order placed',
    'orderPlacedHint': 'We will contact you to confirm',
    'toHome': 'Back to home',
    'orders': 'My orders',
    'noOrders': 'No orders yet',
    'order': 'Order',
    'contacts': 'Contacts',
    'about': 'About',
    'workHours': 'Opening hours',
    'sortPopular': 'Popular',
    'sortPriceAsc': 'Price: low to high',
    'sortPriceDesc': 'Price: high to low',
    'sortName': 'Name',
    'inStockOnly': 'In stock',
    'onSale': 'On sale',
    'retry': 'Retry',
    'loadError': 'Could not load the catalog',
    'minOrder': 'Minimum order',
    'freeDeliveryFrom': 'Free delivery from',
    'products': 'products',
    'repeatOrder': 'Order again',
    'clear': 'Clear',
    'pcs': 'pcs',
    'details': 'Details',
    'promoCode': 'Promo code',
    'apply': 'Apply',
    'promoApplied': 'Promo code applied',
    'promoInvalid': 'Promo code is invalid for this order',
    'discount': 'Discount',
    'bonuses': 'Bonuses',
    'payWithBonuses': 'Pay with bonuses',
    'bonusBalance': 'Bonus balance',
    'cashback': 'cashback in bonuses on every order',
    'willEarn': 'Bonuses you will earn',
    'deliveryTime': 'Delivery time',
    'asap': 'As soon as possible',
    'reviews': 'Reviews',
    'writeReview': 'Write a review',
    'yourRating': 'Your rating',
    'reviewText': 'What did you like?',
    'send': 'Send',
    'reviewThanks': 'Thanks! Your review will appear after moderation',
    'noReviews': 'No reviews yet — be the first',
    'appearance': 'Appearance',
    'themeSystem': 'System',
    'themeLight': 'Light',
    'themeDark': 'Dark',
    'language': 'Language',
    'settings': 'Settings',
    'status_new': 'New',
    'status_confirmed': 'Confirmed',
    'status_delivering': 'On the way',
    'status_done': 'Completed',
    'status_cancelled': 'Cancelled',
  },
};
