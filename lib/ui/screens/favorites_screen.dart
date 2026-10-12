import 'package:flutter/material.dart';

import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final items = [for (final id in state.favorites) ?state.catalog!.product(id)];
    return Scaffold(
      appBar: AppBar(title: Text(S.favorites)),
      body: items.isEmpty
          ? EmptyState(icon: Icons.favorite_border, title: S.emptyFavorites, hint: S.emptyFavoritesHint)
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
                SliverProductGrid(products: items),
                const SliverToBoxAdapter(child: BottomSpace(32)),
              ],
            ),
    );
  }
}
