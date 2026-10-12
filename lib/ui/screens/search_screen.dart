import 'package:flutter/material.dart';

import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = AppState.of(context).catalog!;
    final results = catalog.search(_query);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: S.searchHint,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _controller.clear();
                      _query = '';
                    }),
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: _query.trim().isEmpty
          ? _Suggestions(
              onPick: (s) => setState(() {
                _controller.text = s;
                _query = s;
              }),
            )
          : results.isEmpty
          ? EmptyState(icon: Icons.search_off, title: S.nothingFound)
          : CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverProductGrid(products: results),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Suggestions({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final catalog = AppState.of(context).catalog!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(S.categories, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in catalog.categories)
              ActionChip(avatar: Icon(categoryIcon(c.icon), size: 18), label: Text(c.title), onPressed: () => onPick(c.title)),
          ],
        ),
      ],
    );
  }
}
