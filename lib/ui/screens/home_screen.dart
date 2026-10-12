import 'dart:async';

import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/order_service.dart';
import '../glass.dart';
import '../motion.dart';
import '../system_prefs.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import '../widgets/stories.dart';
import 'catalog_screen.dart';
import 'home_layouts.dart';
import 'product_list_screen.dart';
import 'product_screen.dart';
import 'search_screen.dart';
import '../../core/features.dart';

/// Главная: раскладка зависит от brand.style.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => switch (brand.style) {
    UiStyle.shop => const ShopHome(),
    UiStyle.menu => const MenuHome(),
    UiStyle.boutique => const BoutiqueHome(),
    UiStyle.grocery => const GroceryHome(),
    UiStyle.showroom => const ShowroomHome(),
    UiStyle.services => const SalonHome(),
  };
}

void openSearch(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));

class ShopHome extends StatelessWidget {
  const ShopHome({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = AppState.of(context).catalog!;
    final featured = catalog.featured;
    final sale = catalog.onSale;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: const Glass(opacity: 0.78, border: false, child: SizedBox.expand()),
          title: const BrandLogo(),
          actions: [if (brand.contacts.phone != null) IconButton(icon: const Icon(Icons.call_outlined), onPressed: callStore)],
          bottom: has(Feature.search)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(64),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SearchBarButton(onTap: () => openSearch(context)),
                  ),
                )
              : null,
        ),
        const SliverToBoxAdapter(child: StoriesRow()),
        if (has(Feature.banners) && catalog.banners.isNotEmpty)
          SliverToBoxAdapter(
            child: FadeSlideIn(child: AutoBanners(banners: catalog.banners)),
          ),
        SliverToBoxAdapter(child: FadeSlideIn(index: 1, child: SectionHeader(S.categories))),
        SliverToBoxAdapter(
          child: FadeSlideIn(index: 2, child: CategoryStrip(categories: catalog.categories)),
        ),
        if (featured.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              S.featured,
              onMore: () => openProductList(context, title: S.featured, products: featured),
            ),
          ),
          SliverToBoxAdapter(child: ProductStrip(products: featured)),
        ],
        if (sale.isNotEmpty && brand.features.showPrices) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              S.sale,
              onMore: () => openProductList(context, title: S.sale, products: sale),
            ),
          ),
          SliverToBoxAdapter(child: ProductStrip(products: sale)),
        ],
        SliverToBoxAdapter(child: SectionHeader(S.allProducts)),
        SliverProductGrid(products: catalog.products),
        const SliverToBoxAdapter(child: BottomSpace(32)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Общие блоки главных экранов
// ---------------------------------------------------------------------------

class SearchBarButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? hint;
  const SearchBarButton({super.key, required this.onTap, this.hint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(brand.cornerRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(brand.cornerRadius),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.search, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(hint ?? S.searchHint, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

void openBanner(BuildContext context, PromoBanner b) {
  final catalog = AppState.of(context).catalog!;
  final product = b.productId == null ? null : catalog.product(b.productId!);
  final category = catalog.category(b.categoryId);
  if (product != null) {
    openProduct(context, product);
  } else if (category != null) {
    openCategory(context, category);
  }
}

/// Баннеры с автопрокруткой и «живым» масштабом соседних слайдов.
class AutoBanners extends StatefulWidget {
  final List<PromoBanner> banners;
  final double height;
  final double viewportFraction;
  final double titleSize;
  const AutoBanners({super.key, required this.banners, this.height = 170, this.viewportFraction = 0.92, this.titleSize = 24});

  @override
  State<AutoBanners> createState() => _AutoBannersState();
}

class _AutoBannersState extends State<AutoBanners> {
  late final _controller = PageController(viewportFraction: widget.viewportFraction);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (ambientAnimations && widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_controller.hasClients || SystemLook.reduceMotion(context)) return;
        final next = (_page + 1) % widget.banners.length;
        _controller.animateToPage(next, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                var d = 0.0;
                if (_controller.hasClients && _controller.position.haveDimensions) {
                  d = ((_controller.page ?? 0) - i).abs().clamp(0, 1).toDouble();
                }
                return Transform.scale(
                  scale: 1 - d * 0.06,
                  child: Opacity(opacity: 1 - d * 0.3, child: child),
                );
              },
              child: _BannerCard(banner: widget.banners[i], titleSize: widget.titleSize),
            ),
          ),
        ),
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.banners.length; i++)
                  AnimatedContainer(
                    duration: motionMedium,
                    curve: motionCurve,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final PromoBanner banner;
  final double titleSize;
  const _BannerCard({required this.banner, required this.titleSize});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final b = banner;
    final bg = b.color ?? scheme.primary;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Pressable(
        scale: 0.98,
        onTap: () => openBanner(context, b),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(brand.cornerRadius + 4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: bg),
              if (b.image != null) AppImage(src: b.image, color: bg),
              // Декоративные круги — чтобы баннер без фото не был плоским.
              Positioned(
                right: -40,
                top: -50,
                child: Breathing(
                  period: const Duration(seconds: 7),
                  builder: (_, v) => Transform.scale(
                    scale: 1 + v * 0.12,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: fg.withValues(alpha: 0.08)),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -70,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: fg.withValues(alpha: 0.06)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      b.title,
                      style: t.headlineSmall?.copyWith(color: fg, fontSize: titleSize, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                    if (b.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(b.subtitle!, style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 14)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryStrip extends StatelessWidget {
  final List<Category> categories;
  final bool circle;
  const CategoryStrip({super.key, required this.categories, this.circle = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = categories[i];
          return FadeSlideIn(
            index: i,
            offset: const Offset(24, 0),
            child: Pressable(
              onTap: () => openCategory(context, c),
              child: SizedBox(
                width: 76,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(circle ? 40 : brand.cornerRadius),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: AppImage(src: c.image, color: c.color, icon: categoryIcon(c.icon), iconSize: 30),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// «⚡ 40 мин · 150 сом · бесплатно от 1 500» — для еды и продуктов.
class DeliveryInfo extends StatelessWidget {
  final String eta;
  const DeliveryInfo({super.key, required this.eta});

  @override
  Widget build(BuildContext context) {
    final c = brand.checkout;
    final t = Theme.of(context);
    Widget pill(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: t.colorScheme.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text, overflow: TextOverflow.ellipsis, style: t.textTheme.labelMedium),
          ),
        ],
      ),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        pill(Icons.bolt, eta),
        if (c.delivery) pill(Icons.delivery_dining_outlined, c.deliveryFee == 0 ? S.free : formatMoney(c.deliveryFee)),
        if (c.freeDeliveryFrom != null)
          pill(Icons.redeem_outlined, '${S.free.toLowerCase()} от ${formatMoney(c.freeDeliveryFrom!)}'),
      ],
    );
  }
}
