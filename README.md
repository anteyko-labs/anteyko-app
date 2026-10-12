# White-label магазин / каталог + витрина Anteyko

> Материалы для анализа проекта: [docs/handoff/HANDOFF.md](docs/handoff/HANDOFF.md) — сводка, [стенограмма чата](docs/handoff/chat-transcript.md), [скриншоты](docs/handoff/screenshots/).

Шаблон мобильного приложения на Flutter (iOS, Android, Web), который под нового клиента настраивается без правки экранов: бренд, цвета, контакты и функции задаются в одном файле, товары лежат в JSON или в Supabase.

Три режима в одном проекте:

| Режим | Как включить | Что видно |
| --- | --- | --- |
| **Витрина студии** | `showcaseMode = true` в brand_config.dart (сейчас так) | Выбор типа приложения (магазин, кафе, цветы, продукты, мебель, салон) → живое демо с его брендом |
| **Приложение клиента** | `showcaseMode = false` | Сразу магазин с брендом `defaultBrand` |
| **Админка** | открыть `<адрес>/#/admin` (веб) | Заказы, товары, категории, баннеры. Нужен Supabase |

По умолчанию это готовый магазин: главная с баннерами, каталог по категориям, поиск, карточка товара с вариантами (размер/цвет/объём), избранное, корзина, оформление заказа (доставка или самовывоз, способ оплаты) с отправкой в WhatsApp, история заказов и контакты. Корзина, избранное, заказы и данные покупателя сохраняются на устройстве.

## Запуск

```bash
flutter pub get
flutter run
flutter run -d chrome   # или телефон/эмулятор
flutter test            # каталоги, корзина, тарифы, промокоды, бонусы, админка ↔ приложение

# раздать по сети, чтобы открыть с телефона:
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8095 --bind 0.0.0.0 --directory build/web
```

## Тарифы и функции

Три тарифа — функции включаются автоматически, а любую можно включить/выключить вручную в админке (раздел **«Тариф»**):

| | Старт | Бизнес | Премиум |
| --- | :-: | :-: | :-: |
| Каталог, поиск, заявка в WhatsApp | ✓ | ✓ | ✓ |
| Корзина, доставка, время доставки, фильтры, избранное, история заказов | — | ✓ | ✓ |
| Онлайн-запись (для услуг), баннеры, заказы в админке | — | ✓ | ✓ |
| Промокоды, бонусная программа, отзывы, сторис | — | — | ✓ |
| Тёмная тема, English, анимации и «стекло», аналитика продаж | — | — | ✓ |
| Товаров / баннеров | 30 / 1 | 500 / 5 | без лимита |

- Список функций, тарифы и лимиты — [lib/core/features.dart](lib/core/features.dart) (`featureInfo`, `planInfo`).
- Тип бизнеса может запретить функцию (шоуруму не нужна корзина, запись — только для услуг): `brandBlocks`.
- Бонусы, промокоды, время доставки и история работают только вместе с корзиной: `featureRequires`.
- Цены тарифов в витрине — `planPrices` в [lib/showcase/demos.dart](lib/showcase/demos.dart) (**сейчас примерные — замените**).
- В витрине тариф демо переключается на лету (верхняя панель демо), там же кнопка **«Админка»**.

### Где хранятся данные

| Режим | Каталог, заказы, настройки | Админка |
| --- | --- | --- |
| Без Supabase (сейчас) | `LocalStore` — в браузере/на устройстве, при первом запуске заполняется демо-данными (товары, ~50 заказов для аналитики, отзывы) | демо-режим: `/#/admin` или кнопка «Админка» в витрине; кнопка «Сбросить демо-данные» |
| С Supabase | таблицы `products`, `orders`, `app_settings`, `reviews` | `/#/admin`, вход по email |

На сервере (Supabase) промокод и цены проверяет функция `place_order`, бонусы ограничены долей заказа, лимит товаров тарифа — триггером.

## Витрина: как добавить новое демо

1. Положите каталог в `assets/demos/<id>.json` (формат ниже).
2. Добавьте `DemoTemplate` в [lib/showcase/demos.dart](lib/showcase/demos.dart): бренд (цвет, название, функции), заголовок карточки, описание, 3–4 «фишки».
3. `flutter test` проверит, что каталог парсится и ссылки в нём согласованы.

Корзина и избранное у каждого демо свои (хранятся под `brand.id`).

## Новый клиент за 4 шага

0. `showcaseMode = false` в brand_config.dart; бренд клиента — в `defaultBrand`.
1. **Название и ID приложения**
   ```bash
   dart run tool/rebrand.dart --name "Мой магазин" --id kg.myshop.app
   flutter clean
   ```
2. **Бренд**: [lib/brand/brand_config.dart](lib/brand/brand_config.dart): название, слоган, цвет, валюта, контакты, тексты, функции.
3. **Товары**: [assets/catalog.json](assets/catalog.json); картинки кладите в `assets/images/` или указывайте URL.
4. **Иконка и сплэш**: замените `android/app/src/main/res/mipmap-*` и `ios/Runner/Assets.xcassets/AppIcon.appiconset` (или подключите `flutter_launcher_icons`).

## brand_config.dart: что настраивается

| Поле | Что делает |
| --- | --- |
| `appName`, `tagline`, `about` | Название, слоган, текст «О нас» |
| `logoAsset` | Картинка-логотип (`assets/images/logo.png`). `null` даёт текстовый логотип |
| `primaryColor` | Палитра всего приложения строится от этого цвета (Material 3) |
| `saleColor`, `cornerRadius`, `fontFamily`, `themeMode` | Цвет скидок, скругления, шрифт, светлая/тёмная тема |
| `locale` | `ru` или `en`. Тексты в [lib/brand/strings.dart](lib/brand/strings.dart), туда же добавляется новый язык |
| `currency` | Символ, позиция, копейки, разделитель тысяч |
| `contacts` | Телефон, WhatsApp, Telegram, Instagram, почта, адрес, карта, часы работы. Пустые поля скрываются |
| `checkout` | Доставка/самовывоз, цена доставки, бесплатно от суммы, минимальный заказ, способы оплаты, канал заказа |

### Стиль интерфейса (`style`)

Данные и логика общие, а экраны разные — выбирается одним полем:

| `UiStyle` | Для кого | Что отличается |
| --- | --- | --- |
| `shop` | магазины одежды, электроники | баннеры с автопрокруткой, ленты, сетка карточек с «+» |
| `menu` | кафе, доставка еды | меню с липкими вкладками категорий, блюда строкой, выбор добавок в шторке, плавающая панель корзины |
| `boutique` | цветы, подарки, украшения | большой hero, шрифт с засечками, высокие карточки |
| `grocery` | продукты, аптеки | плитки категорий, полки товаров, «− 2 +» прямо на карточке, прогресс до бесплатной доставки |
| `showroom` | мебель, ремонт, B2B | минимализм, нумерованные разделы, большие фото, заявка на замер |
| `services` | салоны, клиники, сервисы | прайс с длительностью, выбор мастера, даты и времени, подтверждение записи |

Плюс `fontFamily` / `headingFont` (шрифты в `assets/fonts`: Manrope, Rubik, Nunito, Montserrat, Cormorant Garamond, Playfair Display, Unbounded) и `themeMode` (кафе в демо — тёмное).

### Функции (`features`)

| Флаг | Если `false` |
| --- | --- |
| `cart` | **Режим витрины**: нет корзины и оформления, на товаре кнопка «Связаться» (WhatsApp → Telegram → звонок) |
| `showPrices` | Везде «Цена по запросу», сортировка по цене и скидки скрываются |
| `favorites`, `search`, `banners`, `orderHistory` | Вкладка/кнопка/блок пропадает |

Типовые сочетания:
- **Магазин с доставкой**: всё по умолчанию.
- **Каталог-витрина** (мебель, стройматериалы, B2B): `cart: false`.
- **Шоурум без цен**: `cart: false, showPrices: false`.
- **Ресторан/кофейня**: `unit: "порц."` у товаров, `pickup: true`, опции «Размер»/«Добавки».

## Формат catalog.json

```jsonc
{
  "banners": [
    { "title": "Скидки до −30%", "subtitle": "…", "color": "#2F5BEA",
      "image": "assets/images/banner1.jpg", "categoryId": "clothes" }  // или "productId"
  ],
  "categories": [
    { "id": "clothes", "title": "Одежда", "icon": "clothes", "color": "#5B6CFF",
      "image": null }
  ],
  "products": [
    {
      "id": "p1", "categoryId": "clothes", "title": "Футболка",
      "price": 890, "oldPrice": 1190,        // oldPrice → бейдж скидки
      "unit": "шт",                           // необязательно: «890 сом / кг»
      "images": ["https://…/1.jpg", "assets/images/p1.jpg"],
      "description": "…",
      "badges": ["Хит"],
      "options": [{ "name": "Размер", "values": ["S", "M", "L"] }],
      "specs": { "Состав": "100% хлопок" },
      "inStock": true, "featured": true       // featured → блок «Популярное»
    }
  ]
}
```

`price: null` у товара означает «Цена по запросу» только для этого товара. Без картинки показывается заглушка в цвете категории.

Иконки категорий (`icon`): `clothes shoes accessories electronics phone audio home kitchen beauty sport kids pets food grocery coffee bakery flowers jewelry books health tools auto gifts services`.

## Админка (Supabase)

1. Создайте проект на [supabase.com](https://supabase.com) (бесплатного тарифа хватает на старт).
2. SQL Editor → вставьте и выполните [supabase/schema.sql](supabase/schema.sql), затем (по желанию) [supabase/seed.sql](supabase/seed.sql) — демо-товары.
3. Authentication → Users → **Add user**: email и пароль владельца. В Authentication → Sign In / Providers отключите «Allow new users to sign up».
4. SQL Editor: `insert into public.admins(email) values ('owner@example.com');`
5. Project Settings → API: скопируйте Project URL и publishable (anon) key в `supabaseUrl` / `supabaseKey` в brand_config.dart.
6. `flutter build web --release` и откройте `<адрес>/#/admin`.

После этого приложение берёт каталог из базы (изменения в админке видны после перезапуска), а заказы сохраняются в таблицу `orders` через функцию `place_order`, которая **пересчитывает цены на сервере** — подменить сумму из приложения нельзя. Права (RLS): каталог читают все, меняют только адреса из `admins`; заказы видят только админы.

Админка — это тот же Flutter-проект ([lib/admin/](lib/admin/)), её можно задеплоить отдельным сайтом (`build/web` на любой статический хостинг: Vercel, Netlify, Cloudflare Pages).

## Подключение своего бэкенда вместо Supabase

Точки расширения находятся в [lib/main.dart](lib/main.dart):

- **Каталог из API/CMS**: реализуйте `CatalogRepository.load()` ([lib/core/catalog_repository.dart](lib/core/catalog_repository.dart)), вернув `Catalog.fromJson(...)` от ответа сервера в том же формате.
- **Заказы на сервер / в CRM / в бот**: реализуйте `OrderSubmitter.submit(order)` ([lib/core/order_service.dart](lib/core/order_service.dart)). Для отправки JSON есть `order.toJson()`, для текста `orderToText(order)`.

Канал по умолчанию (`checkout.orderChannel`): `whatsapp`, `telegram`, `email` или `none` (заказ остаётся только в истории приложения).

## Структура

```
lib/
  showcase/     витрина студии: demos.dart (список демо), showcase_app.dart
  admin/        админка: обзор (аналитика), заказы, товары, категории, баннеры,
                промокоды, отзывы, тариф и функции; local_admin_api — демо без сервера
  brand/        brand_config.dart, strings.dart    ← меняется под клиента
  core/         features (тарифы), app_state, backend / local_store / supabase_backend,
                модели, заказы, форматирование
  ui/theme.dart тема из brand
  ui/screens/   shell (вкладки), главная, каталог, список, товар, поиск,
                избранное, корзина, оформление, «Ещё»
  ui/widgets/   карточка товара, картинка-заглушка, цена, степпер…
assets/catalog.json  каталог по умолчанию (без Supabase)
assets/demos/        каталоги демо витрины
supabase/            schema.sql (таблицы, права, place_order), seed.sql
tool/rebrand.dart    название и bundle id
```
