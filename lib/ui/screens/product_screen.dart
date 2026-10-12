import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../glass.dart';
import '../motion.dart';
import '../widgets/cart_actions.dart';
import '../widgets/fly_to_cart.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import '../widgets/reviews.dart';
import 'booking_sheet.dart';
import '../../core/features.dart';

/// [heroTag] — тег картинки в карточке, из которой открыли товар: фото «вырастает» в экран.
void openProduct(BuildContext context, Product p, {Object? heroTag}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductScreen(product: p, heroTag: heroTag),
    ),
  );
}

/// Уникальный тег Hero для карточки: один товар может быть на экране несколько раз.
String heroTagFor(BuildContext context, Product p) => 'product-${p.id}-${identityHashCode(context)}';

List<Widget> _stagger(List<Widget> items) => [for (final (i, w) in items.indexed) FadeSlideIn(index: i + 1, child: w)];

class ProductScreen extends StatefulWidget {
  final Product product;
  final Object? heroTag;
  const ProductScreen({super.key, required this.product, this.heroTag});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late final Map<String, String> _selected = {
    for (final o in widget.product.options)
      if (o.values.isNotEmpty) o.name: o.values.first,
  };
  int _qty = 1;
  int _image = 0;

  Product get p => widget.product;

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final t = Theme.of(context);
    final category = state.catalog?.category(p.categoryId);
    final images = p.images.isEmpty ? <String?>[null] : p.images;
    final related = state.catalog!.inCategory(p.categoryId).where((x) => x.id != p.id).take(10).toList();

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: MediaQuery.sizeOf(context).width.clamp(0, 520).toDouble(),
            leading: const Padding(
              padding: EdgeInsets.all(6),
              child: Glass(borderRadius: BorderRadius.all(Radius.circular(22)), child: BackButton()),
            ),
            actions: [
              if (has(Feature.favorites))
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Glass(
                    borderRadius: const BorderRadius.all(Radius.circular(22)),
                    child: FavoriteButton(product: p, filled: false),
                  ),
                ),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _image = i),
                    itemBuilder: (_, i) {
                      final img = AppImage(
                        src: images[i],
                        color: category?.color,
                        icon: categoryIcon(category?.icon),
                        iconSize: 96,
                      );
                      return i == 0 ? Hero(tag: widget.heroTag ?? 'product-${p.id}', child: img) : img;
                    },
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < images.length; i++)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _image ? t.colorScheme.primary : t.colorScheme.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList.list(
              children: _stagger([
                if (p.badges.isNotEmpty || p.isOnSale)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        if (p.isOnSale && brand.features.showPrices) Tag('−${p.discountPercent}%', color: brand.saleColor),
                        for (final b in p.badges) Tag(b),
                      ],
                    ),
                  ),
                Text(p.title, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: PriceView(product: p, fontSize: 22)),
                    RatingBadge(product: p, size: 15),
                  ],
                ),
                if (!p.inStock) ...[
                  const SizedBox(height: 6),
                  Text(
                    S.outOfStock,
                    style: TextStyle(color: t.colorScheme.error, fontWeight: FontWeight.w600),
                  ),
                ],
                for (final o in p.options) ...[
                  const SizedBox(height: 20),
                  Text(o.name, style: t.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in o.values)
                        ChoiceChip(
                          label: Text(v),
                          selected: _selected[o.name] == v,
                          onSelected: (_) => setState(() => _selected[o.name] = v),
                        ),
                    ],
                  ),
                ],
                if (has(Feature.cart) && p.inStock && p.price != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(S.quantity, style: t.textTheme.titleSmall),
                      const Spacer(),
                      QuantityStepper(value: _qty, min: 1, onChanged: (v) => setState(() => _qty = v)),
                    ],
                  ),
                ],
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(S.description, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(p.description, style: t.textTheme.bodyLarge?.copyWith(height: 1.45)),
                ],
                if (p.specs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(S.specs, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final e in p.specs.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(e.key, style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(e.value, textAlign: TextAlign.end)),
                        ],
                      ),
                    ),
                ],
                ReviewsSection(product: p),
              ]),
            ),
          ),
          if (related.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(category?.title ?? S.allProducts)),
            SliverToBoxAdapter(child: ProductStrip(products: related)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: _BuyButton(product: p, quantity: _qty, options: _selected),
      ),
    );
  }
}

class _BuyButton extends StatefulWidget {
  final Product product;
  final int quantity;
  final Map<String, String> options;
  const _BuyButton({required this.product, required this.quantity, required this.options});

  @override
  State<_BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<_BuyButton> {
  bool _added = false;

  Future<void> _add() async {
    AppState.of(context).addAndFly(context, widget.product, options: widget.options, quantity: widget.quantity);
    setState(() => _added = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _added = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final label = brand.contactLabel ?? S.contactUs;

    if (brand.style == UiStyle.services) {
      return FilledButton.icon(
        icon: const Icon(Icons.event_available),
        label: Text(label),
        onPressed: () => has(Feature.booking) ? openBooking(context, p) : openRequest(context, p),
      );
    }
    if (!canBuy(p) && p.inStock) {
      return FilledButton.icon(
        icon: const Icon(Icons.chat_outlined),
        label: Text(label),
        onPressed: () => openRequest(context, p),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: motionMedium,
      curve: motionCurve,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: _added ? const Color(0xFF16A34A) : null),
        onPressed: p.inStock ? _add : null,
        child: AnimatedSwitcher(
          duration: motionMedium,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
              child: c,
            ),
          ),
          child: Row(
            key: ValueKey(_added),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_added ? Icons.check_rounded : Icons.add_shopping_cart, color: _added ? Colors.white : scheme.onPrimary),
              const SizedBox(width: 8),
              Text(_added ? S.inCart : (p.inStock ? S.addToCart : S.outOfStock)),
            ],
          ),
        ),
      ),
    );
  }
}
