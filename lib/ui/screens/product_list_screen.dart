import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/features.dart';
import '../../core/models.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

void openProductList(BuildContext context, {required String title, required List<Product> products}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductListScreen(title: title, products: products),
    ),
  );
}

enum SortMode { popular, priceAsc, priceDesc, name }

String sortLabel(SortMode m) => switch (m) {
  SortMode.popular => S.sortPopular,
  SortMode.priceAsc => S.sortPriceAsc,
  SortMode.priceDesc => S.sortPriceDesc,
  SortMode.name => S.sortName,
};

class ProductListScreen extends StatefulWidget {
  final String title;
  final List<Product> products;
  const ProductListScreen({super.key, required this.title, required this.products});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  SortMode _sort = SortMode.popular;
  bool _inStockOnly = false;
  bool _saleOnly = false;

  List<Product> get _visible {
    final list = widget.products.where((p) => !_inStockOnly || p.inStock).where((p) => !_saleOnly || p.isOnSale).toList();
    num price(Product p) => p.price ?? double.infinity;
    switch (_sort) {
      case SortMode.popular:
        list.sort((a, b) => (b.featured ? 1 : 0) - (a.featured ? 1 : 0));
      case SortMode.priceAsc:
        list.sort((a, b) => price(a).compareTo(price(b)));
      case SortMode.priceDesc:
        list.sort((a, b) => price(b).compareTo(price(a)));
      case SortMode.name:
        list.sort((a, b) => a.title.compareTo(b.title));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final prices = brand.features.showPrices;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: CustomScrollView(
        slivers: [
          if (has(Feature.filters))
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  spacing: 8,
                  children: [
                    if (prices)
                      MenuAnchor(
                        builder: (context, controller, _) => ActionChip(
                          avatar: const Icon(Icons.sort, size: 18),
                          label: Text(sortLabel(_sort)),
                          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                        ),
                        menuChildren: [
                          for (final m in SortMode.values)
                            MenuItemButton(
                              leadingIcon: Icon(m == _sort ? Icons.check : null),
                              onPressed: () => setState(() => _sort = m),
                              child: Text(sortLabel(m)),
                            ),
                        ],
                      ),
                    FilterChip(
                      label: Text(S.inStockOnly),
                      selected: _inStockOnly,
                      onSelected: (v) => setState(() => _inStockOnly = v),
                    ),
                    if (prices && widget.products.any((p) => p.isOnSale))
                      FilterChip(label: Text(S.onSale), selected: _saleOnly, onSelected: (v) => setState(() => _saleOnly = v)),
                  ],
                ),
              ),
            ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.search_off, title: S.nothingFound),
            )
          else
            SliverProductGrid(products: visible),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
