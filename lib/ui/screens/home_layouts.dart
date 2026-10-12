import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/order_service.dart';
import '../glass.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import '../widgets/stories.dart';
import 'booking_sheet.dart';
import 'catalog_screen.dart';
import 'home_screen.dart';
import 'shell.dart';
import '../../core/features.dart';

// ===========================================================================
//  menu — кафе: шапка, промо, липкие вкладки категорий, блюда секциями
// ===========================================================================

class MenuHome extends StatefulWidget {
  const MenuHome({super.key});

  @override
  State<MenuHome> createState() => _MenuHomeState();
}

class _MenuHomeState extends State<MenuHome> {
  final _scroll = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};
  final _chipKeys = <String, GlobalKey>{};
  final _viewportKey = GlobalKey();
  String? _active;
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Подсвечивает категорию, секция которой сейчас под вкладками.
  void _onScroll() {
    if (_jumping) return;
    final viewport = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null) return;
    final top = viewport.localToGlobal(Offset.zero).dy + 140;
    String? current;
    for (final e in _sectionKeys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= top) current = e.key;
    }
    current ??= _sectionKeys.keys.firstOrNull;
    if (current != _active) {
      setState(() => _active = current);
      final chip = _chipKeys[current]?.currentContext;
      if (chip != null) Scrollable.ensureVisible(chip, alignment: 0.5, duration: motionMedium);
    }
  }

  Future<void> _jump(String id) async {
    final ctx = _sectionKeys[id]?.currentContext;
    if (ctx == null) return;
    setState(() => _active = id);
    _jumping = true;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      alignment: 0.0,
    );
    _jumping = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final catalog = AppState.of(context).catalog!;
    final cats = catalog.categories.where((c) => catalog.inCategory(c.id).isNotEmpty).toList();
    _active ??= cats.firstOrNull?.id;

    return Scaffold(
      key: _viewportKey,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: FadeSlideIn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              brand.appName,
                              style: t.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
                            ),
                            const SizedBox(height: 4),
                            Text(brand.tagline, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 14),
                            const DeliveryInfo(eta: '30–40 мин'),
                          ],
                        ),
                      ),
                    ),
                    if (has(Feature.search))
                      IconButton.filledTonal(onPressed: () => openSearch(context), icon: const Icon(Icons.search)),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: StoriesRow(padding: EdgeInsets.fromLTRB(20, 10, 16, 0))),
          if (has(Feature.banners) && catalog.banners.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FadeSlideIn(
                  index: 1,
                  child: AutoBanners(banners: catalog.banners, height: 132, viewportFraction: 0.82, titleSize: 20),
                ),
              ),
            ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsDelegate(
              height: 60,
              color: t.colorScheme.surface,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: cats.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final on = c.id == _active;
                  return AnimatedContainer(
                    key: _chipKeys.putIfAbsent(c.id, GlobalKey.new),
                    duration: motionMedium,
                    curve: motionCurve,
                    decoration: BoxDecoration(
                      color: on ? t.colorScheme.primary : t.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () => _jump(c.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              categoryIcon(c.icon),
                              size: 16,
                              color: on ? t.colorScheme.onPrimary : t.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              c.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: on ? t.colorScheme.onPrimary : t.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Секции не ленивые — чтобы прокрутка к любой категории работала сразу.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in cats) ...[
                    Padding(
                      key: _sectionKeys.putIfAbsent(c.id, GlobalKey.new),
                      padding: const EdgeInsets.only(top: 24, bottom: 4),
                      child: Text(c.title, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    for (final (i, p) in catalog.inCategory(c.id).indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      FadeSlideIn(
                        index: i,
                        child: MenuTile(product: p),
                      ),
                    ],
                  ],
                  const BottomSpace(110),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Color color;
  final Widget child;
  _TabsDelegate({required this.height, required this.color, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Glass(
    tint: color,
    opacity: 0.8,
    border: false,
    child: Material(type: MaterialType.transparency, child: child),
  );

  @override
  bool shouldRebuild(_TabsDelegate old) => true;
}

// ===========================================================================
//  boutique — цветы: большой hero с типографикой, мягкие карточки
// ===========================================================================

class BoutiqueHome extends StatelessWidget {
  const BoutiqueHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final catalog = AppState.of(context).catalog!;
    final featured = catalog.featured;
    final c = t.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: const Glass(opacity: 0.78, border: false, child: SizedBox.expand()),
          centerTitle: true,
          title: Text(
            brand.appName,
            style: t.textTheme.headlineMedium?.copyWith(color: c.primary, fontStyle: FontStyle.italic),
          ),
          leading: !has(Feature.search) ? null : IconButton(icon: const Icon(Icons.search), onPressed: () => openSearch(context)),
          actions: [if (brand.contacts.phone != null) IconButton(icon: const Icon(Icons.call_outlined), onPressed: callStore)],
        ),
        const SliverToBoxAdapter(child: StoriesRow()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FadeSlideIn(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(brand.cornerRadius + 6),
                child: SizedBox(
                  height: 360,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [c.primary, shiftHue(c.primary, -32, lighten: 0.12)],
                          ),
                        ),
                      ),
                      // Плавающие «лепестки».
                      for (final (i, pos) in const [
                        (0, Offset(0.72, 0.12)),
                        (1, Offset(0.15, 0.62)),
                        (2, Offset(0.82, 0.7)),
                      ].indexed)
                        Breathing(
                          period: Duration(seconds: 5 + i * 2),
                          builder: (context, v) => Align(
                            alignment: Alignment(pos.$2.dx * 2 - 1, pos.$2.dy * 2 - 1 + v * 0.08),
                            child: Transform.rotate(
                              angle: v * 0.4 + i,
                              child: Icon(
                                Icons.local_florist,
                                size: 70.0 + i * 30,
                                color: Colors.white.withValues(alpha: 0.12 + i * 0.04),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              brand.tagline,
                              style: t.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                height: 1.0,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Соберём сегодня, доставим за 2 часа',
                              style: TextStyle(color: Colors.white70, fontSize: 15),
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: c.primary,
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(horizontal: 22),
                              ),
                              onPressed: () => ShellNav.go(context, ShellTab.catalog),
                              child: const Text('Выбрать букет'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: catalog.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = catalog.categories[i];
                return FadeSlideIn(
                  index: i,
                  offset: const Offset(20, 0),
                  child: ActionChip(
                    avatar: Icon(categoryIcon(cat.icon), size: 18, color: cat.color),
                    label: Text(cat.title),
                    side: BorderSide.none,
                    backgroundColor: (cat.color ?? c.primary).withValues(alpha: 0.12),
                    shape: const StadiumBorder(),
                    onPressed: () => openCategory(context, cat),
                  ),
                );
              },
            ),
          ),
        ),
        if (featured.isNotEmpty) ...[
          SliverToBoxAdapter(child: _SerifHeader('Хиты недели')),
          SliverProductGrid(products: featured),
        ],
        if (has(Feature.banners) && catalog.banners.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: AutoBanners(banners: catalog.banners.skip(1).toList(), height: 140, titleSize: 22),
            ),
          ),
        SliverToBoxAdapter(child: _SerifHeader('Вся коллекция')),
        SliverProductGrid(products: catalog.products.where((p) => !p.featured).toList()),
        const SliverToBoxAdapter(child: BottomSpace(40)),
      ],
    );
  }
}

class _SerifHeader extends StatelessWidget {
  final String text;
  const _SerifHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
    child: Text(text, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontStyle: FontStyle.italic)),
  );
}

// ===========================================================================
//  grocery — продукты: доставка, плитки категорий, полки товаров
// ===========================================================================

class GroceryHome extends StatelessWidget {
  const GroceryHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final catalog = AppState.of(context).catalog!;
    final sale = catalog.onSale;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: const Glass(opacity: 0.78, border: false, child: SizedBox.expand()),
          toolbarHeight: 64,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: t.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.bolt, color: t.colorScheme.onPrimary, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brand.appName, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  Text('Доставка за 30 минут', style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.primary)),
                ],
              ),
            ],
          ),
          bottom: !has(Feature.search)
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SearchBarButton(onTap: () => openSearch(context), hint: 'Молоко, хлеб, фрукты…'),
                  ),
                ),
        ),
        const SliverToBoxAdapter(child: StoriesRow()),
        if (has(Feature.banners) && catalog.banners.isNotEmpty)
          SliverToBoxAdapter(
            child: FadeSlideIn(child: AutoBanners(banners: catalog.banners, height: 120, viewportFraction: 0.88, titleSize: 20)),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 100,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
            itemCount: catalog.categories.length,
            itemBuilder: (_, i) {
              final c = catalog.categories[i];
              return FadeSlideIn(
                index: i,
                child: Pressable(
                  onTap: () => openCategory(context, c),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: (c.color ?? t.colorScheme.primary).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(brand.cornerRadius),
                          ),
                          child: Icon(categoryIcon(c.icon), color: c.color, size: 32),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: t.textTheme.labelMedium?.copyWith(height: 1.1),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 0), child: FreeDeliveryProgress()),
        ),
        if (sale.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader(S.sale)),
          SliverToBoxAdapter(child: ProductStrip(products: sale)),
        ],
        for (final c in catalog.categories)
          if (catalog.inCategory(c.id).isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(c.title, onMore: () => openCategory(context, c))),
            SliverToBoxAdapter(child: ProductStrip(products: catalog.inCategory(c.id))),
          ],
        const SliverToBoxAdapter(child: BottomSpace(110)),
      ],
    );
  }
}

/// «Ещё 520 сом до бесплатной доставки» с анимированной полоской.
class FreeDeliveryProgress extends StatelessWidget {
  final bool compact;
  const FreeDeliveryProgress({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final goal = brand.checkout.freeDeliveryFrom;
    if (goal == null || !has(Feature.cart)) return const SizedBox.shrink();
    final t = Theme.of(context);
    final sum = state.subtotal;
    final left = goal - sum;
    final done = left <= 0;
    final text = sum == 0
        ? 'Бесплатная доставка от ${formatMoney(goal)}'
        : done
        ? 'Доставка будет бесплатной'
        : 'Ещё ${formatMoney(left)} до бесплатной доставки';
    final bar = TweenAnimationBuilder<double>(
      tween: Tween(end: (sum / goal).clamp(0, 1).toDouble()),
      duration: motionSlow,
      curve: motionCurve,
      builder: (_, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 6,
          backgroundColor: t.colorScheme.surfaceContainerHighest,
          color: done ? const Color(0xFF16A34A) : t.colorScheme.primary,
        ),
      ),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(text, style: t.textTheme.labelMedium),
          bar,
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(brand.cornerRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: t.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(text, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                bar,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
//  showroom — мебель: строгий минимализм, большие фото, нумерованные разделы
// ===========================================================================

class ShowroomHome extends StatelessWidget {
  const ShowroomHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final catalog = AppState.of(context).catalog!;
    final hero = catalog.banners.firstOrNull;
    final featured = catalog.featured;
    final upper = t.textTheme.labelMedium?.copyWith(letterSpacing: 3, fontWeight: FontWeight.w600);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          flexibleSpace: const Glass(opacity: 0.78, border: false, child: SizedBox.expand()),
          title: Text(
            brand.appName.toUpperCase(),
            style: t.textTheme.titleMedium?.copyWith(letterSpacing: 5, fontWeight: FontWeight.w600),
          ),
          actions: [if (has(Feature.search)) IconButton(icon: const Icon(Icons.search), onPressed: () => openSearch(context))],
        ),
        const SliverToBoxAdapter(child: StoriesRow()),
        if (has(Feature.banners) && hero != null)
          SliverToBoxAdapter(
            child: FadeSlideIn(
              child: Pressable(
                scale: 0.99,
                onTap: () => openBanner(context, hero),
                child: Container(
                  height: 440,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(brand.cornerRadius)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Breathing(
                        period: const Duration(seconds: 12),
                        builder: (_, v) => Transform.scale(
                          scale: 1.05 + v * 0.05,
                          child: AppImage(
                            src: hero.image,
                            color: hero.color ?? t.colorScheme.primary,
                            icon: Icons.weekend_outlined,
                            iconSize: 160,
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                            stops: [0.35, 1],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('НОВАЯ КОЛЛЕКЦИЯ', style: upper?.copyWith(color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(
                              hero.title,
                              style: t.textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                height: 1.05,
                              ),
                            ),
                            if (hero.subtitle != null) ...[
                              const SizedBox(height: 8),
                              Text(hero.subtitle!, style: const TextStyle(color: Colors.white70)),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Text('СМОТРЕТЬ', style: upper?.copyWith(color: Colors.white)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 8),
            child: Text('КАТАЛОГ', style: upper?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ),
        ),
        SliverList.builder(
          itemCount: catalog.categories.length,
          itemBuilder: (_, i) {
            final c = catalog.categories[i];
            return FadeSlideIn(
              index: i,
              child: InkWell(
                onTap: () => openCategory(context, c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: t.colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          (i + 1).toString().padLeft(2, '0'),
                          style: upper?.copyWith(color: t.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Expanded(child: Text(c.title.toUpperCase(), style: t.textTheme.titleMedium?.copyWith(letterSpacing: 2))),
                      Text(
                        '${catalog.inCategory(c.id).length}',
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (featured.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              child: Text('ИЗБРАННЫЕ МОДЕЛИ', style: upper?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ),
          ),
          SliverProductGrid(products: featured),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: t.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(brand.cornerRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.straighten, color: t.colorScheme.onInverseSurface),
                  const SizedBox(height: 14),
                  Text(
                    'Бесплатный замер\nи дизайн-проект',
                    style: t.textTheme.headlineSmall?.copyWith(
                      color: t.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Дизайнер приедет, снимет размеры и покажет мебель в вашем интерьере в 3D.',
                    style: TextStyle(color: t.colorScheme.onInverseSurface.withValues(alpha: 0.7), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.colorScheme.onInverseSurface,
                      side: BorderSide(color: t.colorScheme.onInverseSurface.withValues(alpha: 0.5)),
                    ),
                    onPressed: () => openRequest(context, null),
                    child: const Text('ЗАПИСАТЬСЯ НА ЗАМЕР', style: TextStyle(letterSpacing: 2)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: BottomSpace(32)),
      ],
    );
  }
}

// ===========================================================================
//  services — салон: онлайн-запись, мастера, услуги по категориям
// ===========================================================================

class SalonHome extends StatefulWidget {
  const SalonHome({super.key});

  @override
  State<SalonHome> createState() => _SalonHomeState();
}

class _SalonHomeState extends State<SalonHome> {
  String? _cat;

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Доброе утро' : (h < 18 ? 'Добрый день' : 'Добрый вечер');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final catalog = AppState.of(context).catalog!;
    final masters = <String>{
      for (final p in catalog.products)
        for (final o in p.options)
          if (o.name == 'Мастер') ...o.values.where((v) => v != 'Любой'),
    }.toList();
    final services = _cat == null ? catalog.featured : catalog.inCategory(_cat!);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting, style: t.textTheme.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
                    Text(brand.appName, style: t.textTheme.displaySmall?.copyWith(color: c.primary)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: StoriesRow()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: FadeSlideIn(
              index: 1,
              child: Pressable(
                onTap: () => ShellNav.go(context, ShellTab.catalog),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(brand.cornerRadius),
                    gradient: LinearGradient(colors: [c.primary, shiftHue(c.primary, -24, lighten: 0.1)]),
                    boxShadow: [BoxShadow(color: c.primary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Онлайн-запись 24/7',
                              style: t.textTheme.titleLarge?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Выберите услугу, мастера и удобное время',
                              style: TextStyle(color: c.onPrimary.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                      Breathing(
                        period: const Duration(seconds: 3),
                        builder: (_, v) => Transform.scale(
                          scale: 1 + v * 0.08,
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: c.onPrimary,
                            child: Icon(Icons.event_available, color: c.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (masters.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader('Наши мастера')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: masters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (_, i) => FadeSlideIn(
                  index: i,
                  offset: const Offset(20, 0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(colors: [c.primary, shiftHue(c.primary, 40, lighten: 0.2), c.primary]),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: c.surface,
                          child: CircleAvatar(
                            radius: 27,
                            backgroundColor: c.primaryContainer,
                            child: Text(
                              masters[i].characters.first,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.onPrimaryContainer),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(masters[i], style: t.textTheme.labelLarge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        if (has(Feature.banners) && catalog.banners.isNotEmpty) ...[
          SliverToBoxAdapter(child: SectionHeader('Акции')),
          SliverToBoxAdapter(child: AutoBanners(banners: catalog.banners, height: 130, titleSize: 20)),
        ],
        SliverToBoxAdapter(child: SectionHeader('Услуги')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Популярное'),
                    selected: _cat == null,
                    onSelected: (_) => setState(() => _cat = null),
                  ),
                ),
                for (final cat in catalog.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(categoryIcon(cat.icon), size: 16),
                      label: Text(cat.title),
                      selected: _cat == cat.id,
                      onSelected: (_) => setState(() => _cat = cat.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: motionMedium,
            child: Padding(
              key: ValueKey(_cat),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final (i, p) in services.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeSlideIn(
                        index: i,
                        child: ServiceTile(product: p),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Card(
              child: Column(
                children: [
                  if (brand.contacts.address != null)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(brand.contacts.address!),
                      trailing: const Icon(Icons.map_outlined),
                      onTap: brand.contacts.mapUrl == null ? null : () => openLink(brand.contacts.mapUrl!),
                    ),
                  if (brand.contacts.workHours != null)
                    ListTile(leading: const Icon(Icons.schedule), title: Text(brand.contacts.workHours!)),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: BottomSpace(32)),
      ],
    );
  }
}
