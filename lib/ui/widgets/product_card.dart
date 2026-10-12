import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../motion.dart';
import '../screens/booking_sheet.dart';
import '../screens/product_screen.dart';
import 'cart_actions.dart';
import 'common.dart';
import 'reviews.dart';
import '../../core/features.dart';

/// Картинка товара в цветах его категории.
class ProductImage extends StatelessWidget {
  final Product product;
  final double iconSize;
  final Object? heroTag;
  const ProductImage({super.key, required this.product, this.iconSize = 40, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final cat = AppState.of(context).catalog?.category(product.categoryId);
    final img = AppImage(src: product.image, color: cat?.color, icon: categoryIcon(cat?.icon), iconSize: iconSize);
    return heroTag == null ? img : Hero(tag: heroTag!, child: img);
  }
}

class FavoriteButton extends StatelessWidget {
  final Product product;
  final bool filled;
  const FavoriteButton({super.key, required this.product, this.filled = true});

  @override
  Widget build(BuildContext context) {
    if (!has(Feature.favorites)) return const SizedBox.shrink();
    final state = AppState.of(context);
    final scheme = Theme.of(context).colorScheme;
    final on = state.isFavorite(product.id);
    return IconButton(
      style: filled ? IconButton.styleFrom(backgroundColor: scheme.surface.withValues(alpha: 0.85)) : null,
      visualDensity: VisualDensity.compact,
      onPressed: () => state.toggleFavorite(product.id),
      icon: AnimatedSwitcher(
        duration: motionMedium,
        transitionBuilder: (c, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
          child: c,
        ),
        child: Icon(
          on ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(on),
          color: on ? brand.saleColor : scheme.onSurface,
          size: 20,
        ),
      ),
    );
  }
}

List<Widget> _badges(Product p) => [
  if (p.isOnSale && brand.features.showPrices) Tag('−${p.discountPercent}%', color: brand.saleColor),
  for (final b in p.badges.take(2)) Tag(b),
];

String? serviceDuration(Product p) =>
    p.specs['Длительность'] ?? p.options.where((o) => o.name == 'Длительность').firstOrNull?.values.first;

// ---------------------------------------------------------------------------
//  shop — классическая карточка в сетке
// ---------------------------------------------------------------------------

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(brand.cornerRadius);
    return Pressable(
      onTap: () => openProduct(context, product, heroTag: heroTagFor(context, product)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(heroTag: heroTagFor(context, product), product: product),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: _badges(product)),
                  ),
                  Positioned(right: 4, top: 4, child: FavoriteButton(product: product)),
                  if (!product.inStock)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: scheme.surface.withValues(alpha: 0.85),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(S.outOfStock, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PriceView(product: product, fontSize: 15)),
              if (canBuy(product)) AddButton(product: product, height: 34),
            ],
          ),
          const SizedBox(height: 2),
          Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          RatingBadge(product: product, size: 12),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  menu — блюдо строкой: текст слева, фото справа с кнопкой
// ---------------------------------------------------------------------------

class MenuTile extends StatelessWidget {
  final Product product;
  const MenuTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = product;
    return Pressable(
      scale: 0.98,
      onTap: () => openProduct(context, p, heroTag: heroTagFor(context, p)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.badges.isNotEmpty || p.isOnSale)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(spacing: 4, children: _badges(p)),
                    ),
                  Text(p.title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    p.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (p.options.isNotEmpty && brand.features.showPrices && p.price != null)
                        Text('от ', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      Expanded(child: PriceView(product: p, fontSize: 16)),
                      RatingBadge(product: p, size: 12),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 116,
              height: 116,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(brand.cornerRadius),
                      child: ProductImage(heroTag: heroTagFor(context, p), product: p, iconSize: 44),
                    ),
                  ),
                  if (canBuy(p)) Positioned(right: 6, bottom: 6, child: AddButton(product: p, height: 34)),
                  if (!p.inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.colorScheme.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(brand.cornerRadius),
                        ),
                        alignment: Alignment.center,
                        child: Text(S.outOfStock, textAlign: TextAlign.center, style: t.textTheme.labelSmall),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  boutique — высокая карточка с крупным фото и заголовком шрифтом бренда
// ---------------------------------------------------------------------------

class BoutiqueCard extends StatelessWidget {
  final Product product;
  const BoutiqueCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = product;
    return Pressable(
      onTap: () => openProduct(context, p, heroTag: heroTagFor(context, p)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(brand.cornerRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(heroTag: heroTagFor(context, p), product: p, iconSize: 56),
                  Positioned(left: 10, top: 10, child: Wrap(spacing: 4, children: _badges(p))),
                  Positioned(right: 6, top: 6, child: FavoriteButton(product: p)),
                  if (canBuy(p)) Positioned(right: 10, bottom: 10, child: AddButton(product: p, height: 40)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            p.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.titleLarge?.copyWith(fontSize: 21, height: 1.1),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: PriceView(product: p, fontSize: 15)),
              RatingBadge(product: p, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  grocery — компактная карточка с +/− внизу
// ---------------------------------------------------------------------------

class GroceryCard extends StatelessWidget {
  final Product product;
  const GroceryCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = product;
    return Pressable(
      onTap: () => openProduct(context, p, heroTag: heroTagFor(context, p)),
      child: Container(
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(brand.cornerRadius),
          border: Border.all(color: t.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(brand.cornerRadius * 0.7),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(heroTag: heroTagFor(context, p), product: p, iconSize: 30),
                    Positioned(left: 4, top: 4, child: Wrap(spacing: 4, children: _badges(p).take(1).toList())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            PriceView(product: p, fontSize: 14),
            Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(height: 1.2)),
            const SizedBox(height: 6),
            AddButton(product: p, expanded: true, height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  showroom — широкая карточка в одну колонку, строгая типографика
// ---------------------------------------------------------------------------

class ShowroomCard extends StatelessWidget {
  final Product product;
  const ShowroomCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = product;
    final cat = AppState.of(context).catalog?.category(p.categoryId);
    return Pressable(
      scale: 0.985,
      onTap: () => openProduct(context, p, heroTag: heroTagFor(context, p)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(brand.cornerRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(heroTag: heroTagFor(context, p), product: p, iconSize: 72),
                  Positioned(left: 12, top: 12, child: Wrap(spacing: 4, children: _badges(p))),
                  Positioned(right: 6, top: 6, child: FavoriteButton(product: p)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            (cat?.title ?? '').toUpperCase(),
            style: t.textTheme.labelSmall?.copyWith(letterSpacing: 2, color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 20),
                ),
              ),
              Icon(Icons.arrow_outward, color: t.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: PriceView(product: p, fontSize: 15)),
              RatingBadge(product: p, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  services — услуга: название, длительность, цена и «Записаться»
// ---------------------------------------------------------------------------

class ServiceTile extends StatelessWidget {
  final Product product;
  const ServiceTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = product;
    final dur = serviceDuration(p);
    final accent = AppState.of(context).catalog?.category(p.categoryId)?.color ?? t.colorScheme.primary;
    final price = p.price == null ? S.priceOnRequest : '${p.options.isNotEmpty ? 'от ' : ''}${formatPrice(p.price)}';
    return Pressable(
      scale: 0.98,
      onTap: () => openProduct(context, p, heroTag: heroTagFor(context, p)),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(brand.cornerRadius),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            price,
                            style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: t.colorScheme.primary),
                          ),
                          if (dur != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule, size: 14, color: t.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(dur, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => has(Feature.booking) ? openBooking(context, p) : openRequest(context, p),
                    child: Text(brand.contactLabel ?? S.contactUs),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Списки, которые сами выбирают вид карточки по brand.style
// ---------------------------------------------------------------------------

/// Товары для CustomScrollView (каталог, поиск, избранное, главная).
class SliverProductGrid extends StatelessWidget {
  final List<Product> products;
  const SliverProductGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    Widget item(int i, Widget w) => FadeSlideIn(index: i, child: w);
    const pad = EdgeInsets.symmetric(horizontal: 16);

    switch (brand.style) {
      case UiStyle.menu:
        return SliverPadding(
          padding: pad,
          sliver: SliverList.separated(
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => item(i, MenuTile(product: products[i])),
          ),
        );
      case UiStyle.services:
        return SliverPadding(
          padding: pad,
          sliver: SliverList.separated(
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => item(i, ServiceTile(product: products[i])),
          ),
        );
      case UiStyle.showroom:
        return SliverPadding(
          padding: pad,
          sliver: SliverGrid.builder(
            // Высота ячейки = фото 4:3 + подпись.
            gridDelegate: ExtentGridDelegate(
              maxCrossAxisExtent: 560,
              mainAxisSpacing: 32,
              crossAxisSpacing: 20,
              extent: (w) => w * 3 / 4 + 100,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => item(i, ShowroomCard(product: products[i])),
          ),
        );
      case UiStyle.boutique:
        return SliverPadding(
          padding: pad,
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 24,
              crossAxisSpacing: 14,
              childAspectRatio: 0.56,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => item(i, BoutiqueCard(product: products[i])),
          ),
        );
      case UiStyle.grocery:
        return SliverPadding(
          padding: pad,
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.5,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => item(i, GroceryCard(product: products[i])),
          ),
        );
      case UiStyle.shop:
        return SliverPadding(
          padding: pad,
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 20,
              crossAxisSpacing: 12,
              childAspectRatio: 0.53,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => item(i, ProductCard(product: products[i])),
          ),
        );
    }
  }
}

/// Сетка, где высота ячейки вычисляется из её ширины.
class ExtentGridDelegate extends SliverGridDelegate {
  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double Function(double width) extent;
  const ExtentGridDelegate({
    required this.maxCrossAxisExtent,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.extent,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final cross = constraints.crossAxisExtent;
    final count = (cross / (maxCrossAxisExtent + crossAxisSpacing)).ceil().clamp(1, 99);
    final w = (cross - crossAxisSpacing * (count - 1)) / count;
    final h = extent(w);
    return SliverGridRegularTileLayout(
      crossAxisCount: count,
      mainAxisStride: h + mainAxisSpacing,
      crossAxisStride: w + crossAxisSpacing,
      childMainAxisExtent: h,
      childCrossAxisExtent: w,
      reverseCrossAxis: false,
    );
  }

  @override
  bool shouldRelayout(ExtentGridDelegate old) => old.maxCrossAxisExtent != maxCrossAxisExtent;
}

/// Горизонтальная лента (главная, похожие товары).
class ProductStrip extends StatelessWidget {
  final List<Product> products;
  const ProductStrip({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final (double w, double h, Widget Function(Product) card) = switch (brand.style) {
      UiStyle.grocery => (130.0, 250.0, (p) => GroceryCard(product: p)),
      UiStyle.boutique => (190.0, 330.0, (p) => BoutiqueCard(product: p)),
      UiStyle.showroom => (280.0, 330.0, (p) => ShowroomCard(product: p)),
      UiStyle.services => (320.0, 96.0, (p) => ServiceTile(product: p)),
      UiStyle.menu => (170.0, 292.0, (p) => ProductCard(product: p)),
      UiStyle.shop => (160.0, 308.0, (p) => ProductCard(product: p)),
    };
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => FadeSlideIn(
          index: i,
          offset: const Offset(32, 0),
          child: SizedBox(width: w, child: card(products[i])),
        ),
      ),
    );
  }
}
