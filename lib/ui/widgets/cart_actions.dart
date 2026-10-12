import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../motion.dart';
import '../screens/product_screen.dart';
import 'fly_to_cart.dart';
import '../../core/features.dart';

bool canBuy(Product p) => has(Feature.cart) && brand.features.showPrices && p.price != null && p.inStock;

/// Добавить товар в корзину; если у него есть варианты — спросить их в шторке.
Future<void> quickAdd(BuildContext context, Product p) async {
  final state = AppState.of(context);
  if (p.options.isEmpty) {
    state.addAndFly(context, p);
    return;
  }
  final picked = await showModalBottomSheet<Map<String, String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _OptionsSheet(product: p),
  );
  if (picked != null && context.mounted) state.addAndFly(context, p, options: picked);
}

class _OptionsSheet extends StatefulWidget {
  final Product product;
  const _OptionsSheet({required this.product});

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late final Map<String, String> _sel = {
    for (final o in widget.product.options)
      if (o.values.isNotEmpty) o.name: o.values.first,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = widget.product;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.title, style: t.textTheme.titleLarge),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(p.description, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ],
            for (final o in p.options) ...[
              const SizedBox(height: 16),
              Text(o.name, style: t.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in o.values)
                    ChoiceChip(label: Text(v), selected: _sel[o.name] == v, onSelected: (_) => setState(() => _sel[o.name] = v)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _sel),
                child: Text('${S.addToCart} · ${formatPrice(p.price)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопка «+», которая после добавления превращается в «− 2 +».
/// Для товаров с вариантами показывает количество и открывает выбор.
class AddButton extends StatelessWidget {
  final Product product;
  final bool expanded;
  final double height;
  const AddButton({super.key, required this.product, this.expanded = false, this.height = 36});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final scheme = Theme.of(context).colorScheme;
    final line = product.options.isEmpty ? state.plainLine(product.id) : null;
    final qty = line?.quantity ?? 0;
    final radius = BorderRadius.circular((brand.cornerRadius * 0.75).clamp(4, height / 2));

    if (!canBuy(product)) {
      return SizedBox(
        height: height,
        width: expanded ? double.infinity : null,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, height),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          onPressed: () => openProduct(context, product),
          child: Text(product.inStock ? S.details : S.outOfStock, style: const TextStyle(fontSize: 13)),
        ),
      );
    }

    final Widget child = qty == 0
        ? Material(
            key: const ValueKey('add'),
            color: scheme.primary,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: () => quickAdd(context, product),
              child: SizedBox(
                height: height,
                width: expanded ? double.infinity : height,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: scheme.onPrimary, size: 20),
                    if (expanded) ...[
                      const SizedBox(width: 4),
                      Text(
                        S.addToCart,
                        style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        : Container(
            key: const ValueKey('stepper'),
            height: height,
            width: expanded ? double.infinity : null,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: radius),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepBtn(icon: Icons.remove, onTap: () => state.setQuantity(line!, qty - 1), size: height),
                BounceOnChange(
                  value: qty,
                  child: Text(
                    '$qty',
                    style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                  ),
                ),
                _StepBtn(icon: Icons.add, onTap: () => state.setQuantity(line!, qty + 1), size: height),
              ],
            ),
          );

    return AnimatedSwitcher(
      duration: motionMedium,
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: a, child: c),
      ),
      child: child,
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _StepBtn({required this.icon, required this.onTap, required this.size});

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: size / 2,
    child: SizedBox(
      width: size,
      height: size,
      child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
    ),
  );
}
