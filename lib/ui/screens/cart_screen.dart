import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';
import 'product_screen.dart';

class CartScreen extends StatelessWidget {
  final VoidCallback onBrowse;
  const CartScreen({super.key, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final catalog = state.catalog!;
    final t = Theme.of(context);
    final checkout = brand.checkout;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.cart),
        actions: [if (state.cart.isNotEmpty) TextButton(onPressed: state.clearCart, child: Text(S.clear))],
      ),
      body: state.cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: S.emptyCart,
              hint: S.emptyCartHint,
              action: FilledButton.tonal(onPressed: onBrowse, child: Text(S.catalog)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                for (final line in state.cart)
                  if (catalog.product(line.productId) case final p?)
                    Dismissible(
                      key: ValueKey(line.key),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => state.removeLine(line),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: t.colorScheme.errorContainer,
                        child: Icon(Icons.delete_outline, color: t.colorScheme.onErrorContainer),
                      ),
                      child: InkWell(
                        onTap: () => openProduct(context, p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(brand.cornerRadius * 0.75),
                                child: SizedBox(
                                  width: 76,
                                  height: 76,
                                  child: AppImage(
                                    src: p.image,
                                    color: catalog.category(p.categoryId)?.color,
                                    icon: categoryIcon(catalog.category(p.categoryId)?.icon),
                                    iconSize: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodyLarge),
                                    if (line.options.isNotEmpty)
                                      Text(
                                        optionsLabel(line.options),
                                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                                      ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            formatPrice((p.price ?? 0) * line.quantity),
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                          ),
                                        ),
                                        QuantityStepper(value: line.quantity, onChanged: (v) => state.setQuantity(line, v)),
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
                const Divider(height: 32),
                _Row(S.subtotal, formatPrice(state.subtotal)),
                if (checkout.delivery && checkout.freeDeliveryFrom != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${S.freeDeliveryFrom} ${formatPrice(checkout.freeDeliveryFrom)}',
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (!state.meetsMinOrder)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${S.minOrder}: ${formatPrice(checkout.minOrder)}', style: TextStyle(color: t.colorScheme.error)),
                  ),
              ],
            ),
      bottomNavigationBar: state.cart.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: state.meetsMinOrder
                    ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()))
                    : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [Text('${S.checkout} · '), AnimatedMoney(state.subtotal)]),
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: bold ? 18 : 15, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class SummaryRow extends _Row {
  const SummaryRow(super.label, super.value, {super.key, super.bold});
}
