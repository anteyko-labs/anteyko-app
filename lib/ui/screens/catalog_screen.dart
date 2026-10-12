import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/models.dart';
import '../motion.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import 'product_list_screen.dart';
import 'search_screen.dart';
import '../../core/features.dart';

void openCategory(BuildContext context, Category c) {
  final catalog = AppState.of(context).catalog!;
  openProductList(context, title: c.title, products: catalog.inCategory(c.id));
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = AppState.of(context).catalog!;
    if (brand.style == UiStyle.services || brand.style == UiStyle.menu) return const _GroupedCatalog();
    return Scaffold(
      appBar: AppBar(
        title: Text(brand.style == UiStyle.showroom ? 'Коллекции' : S.catalog),
        actions: [
          if (has(Feature.search))
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _AllProductsTile(
                count: catalog.products.length,
                onTap: () => openProductList(context, title: S.allProducts, products: catalog.products),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
              itemCount: catalog.categories.length,
              itemBuilder: (_, i) {
                final c = catalog.categories[i];
                return _CategoryTile(category: c, count: catalog.inCategory(c.id).length);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllProductsTile extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _AllProductsTile({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(brand.cornerRadius),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.cornerRadius)),
        leading: Icon(Icons.grid_view_rounded, color: scheme.onPrimaryContainer),
        title: Text(
          S.allProducts,
          style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
        ),
        subtitle: Text('$count ${S.products}', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.7))),
        trailing: Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
        onTap: onTap,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final int count;
  const _CategoryTile({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openCategory(context, category),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(src: category.image, color: category.color, icon: categoryIcon(category.icon), iconSize: 48),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.title, maxLines: 2, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('$count ${S.products}', style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Меню кафе и прайс салона: все позиции, сгруппированные по разделам.
class _GroupedCatalog extends StatelessWidget {
  const _GroupedCatalog();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final catalog = AppState.of(context).catalog!;
    final services = brand.style == UiStyle.services;
    return Scaffold(
      appBar: AppBar(
        title: Text(services ? 'Услуги и цены' : 'Меню'),
        actions: [
          if (has(Feature.search))
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 110 + MediaQuery.paddingOf(context).bottom),
        children: [
          for (final (ci, c) in catalog.categories.indexed)
            if (catalog.inCategory(c.id).isNotEmpty)
              FadeSlideIn(
                index: ci,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 10),
                      child: Row(
                        children: [
                          Icon(categoryIcon(c.icon), color: c.color ?? t.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(c.title, style: t.textTheme.headlineSmall),
                        ],
                      ),
                    ),
                    for (final (i, p) in catalog.inCategory(c.id).indexed)
                      services
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ServiceTile(product: p),
                            )
                          : Column(
                              children: [
                                if (i > 0) const Divider(height: 1),
                                MenuTile(product: p),
                              ],
                            ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
