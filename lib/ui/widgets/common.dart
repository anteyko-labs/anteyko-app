import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/format.dart';
import '../../core/models.dart';

/// Иконки категорий: ключ из catalog.json / админки → иконка.
const categoryIcons = <String, IconData>{
  'clothes': Icons.checkroom,
  'shoes': Icons.ice_skating_outlined,
  'electronics': Icons.devices_other,
  'phone': Icons.smartphone,
  'audio': Icons.headphones,
  'home': Icons.chair_outlined,
  'kitchen': Icons.kitchen_outlined,
  'beauty': Icons.spa_outlined,
  'sport': Icons.sports_basketball_outlined,
  'kids': Icons.toys_outlined,
  'pets': Icons.pets,
  'food': Icons.restaurant,
  'grocery': Icons.local_grocery_store_outlined,
  'coffee': Icons.local_cafe_outlined,
  'bakery': Icons.cake_outlined,
  'flowers': Icons.local_florist_outlined,
  'jewelry': Icons.diamond_outlined,
  'accessories': Icons.watch_outlined,
  'books': Icons.menu_book_outlined,
  'health': Icons.local_pharmacy_outlined,
  'tools': Icons.build_outlined,
  'auto': Icons.directions_car_outlined,
  'gifts': Icons.card_giftcard,
  'services': Icons.design_services_outlined,
  'pizza': Icons.local_pizza_outlined,
  'burger': Icons.lunch_dining_outlined,
  'drinks': Icons.local_bar_outlined,
  'juice': Icons.local_drink_outlined,
  'salad': Icons.eco_outlined,
  'dessert': Icons.icecream_outlined,
  'sushi': Icons.set_meal_outlined,
  'soup': Icons.ramen_dining_outlined,
  'breakfast': Icons.egg_alt_outlined,
  'fruit': Icons.apple,
  'meat': Icons.kebab_dining_outlined,
  'dairy': Icons.egg_outlined,
  'plants': Icons.yard_outlined,
  'party': Icons.celebration_outlined,
  'haircut': Icons.content_cut,
  'nails': Icons.back_hand_outlined,
  'face': Icons.face_retouching_natural,
  'massage': Icons.self_improvement,
  'sofa': Icons.weekend_outlined,
  'bed': Icons.bed_outlined,
  'table': Icons.table_restaurant_outlined,
  'light': Icons.light_outlined,
  'wardrobe': Icons.door_sliding_outlined,
};

IconData categoryIcon(String? key) => categoryIcons[key] ?? Icons.category_outlined;

/// Картинка товара/категории: URL, asset или аккуратная заглушка, если картинки нет.
class AppImage extends StatelessWidget {
  final String? src;
  final Color? color;
  final IconData icon;
  final double iconSize;

  const AppImage({super.key, this.src, this.color, this.icon = Icons.image_outlined, this.iconSize = 40});

  @override
  Widget build(BuildContext context) {
    final s = src;
    Widget fallback() => _Placeholder(color: color, icon: icon, iconSize: iconSize);
    if (s == null || s.isEmpty) return fallback();
    if (s.startsWith('data:')) {
      return Image.memory(UriData.parse(s).contentAsBytes(), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback());
    }
    if (s.startsWith('http')) {
      return Image.network(s, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback());
    }
    return Image.asset(s, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback());
  }
}

class _Placeholder extends StatelessWidget {
  final Color? color;
  final IconData icon;
  final double iconSize;
  const _Placeholder({this.color, required this.icon, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: dark ? 0.35 : 0.18),
            base.withValues(alpha: dark ? 0.15 : 0.06),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: base.withValues(alpha: 0.8)),
      ),
    );
  }
}

class PriceView extends StatelessWidget {
  final Product product;
  final double fontSize;
  const PriceView({super.key, required this.product, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showOld = product.isOnSale && brand.features.showPrices;
    final unit = product.unit != null && product.price != null && brand.features.showPrices ? ' / ${product.unit}' : '';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      children: [
        Text(
          '${formatPrice(product.price)}$unit',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: showOld ? brand.saleColor : scheme.onSurface),
        ),
        if (showOld)
          Text(
            formatPrice(product.oldPrice),
            style: TextStyle(fontSize: fontSize * 0.8, color: scheme.onSurfaceVariant, decoration: TextDecoration.lineThrough),
          ),
      ],
    );
  }
}

class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  const Tag(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(
          color: ThemeData.estimateBrightnessForColor(bg) == Brightness.dark ? Colors.white : Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 0});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(brand.cornerRadius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(value <= 1 && min == 0 ? Icons.delete_outline : Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add), onPressed: () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  const SectionHeader(this.title, {super.key, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (onMore != null) TextButton(onPressed: onMore, child: Text(S.seeAll)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.hint, this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: t.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    if (brand.logoAsset != null) {
      return Image.asset(brand.logoAsset!, height: size * 1.4);
    }
    return Text(
      brand.appName,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Отступ в конце списка: [extra] + высота стеклянного меню, под которым идёт контент.
class BottomSpace extends StatelessWidget {
  final double extra;
  const BottomSpace(this.extra, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: extra + MediaQuery.paddingOf(context).bottom);
}

/// Сумма, которая плавно «досчитывается» до нового значения.
class AnimatedMoney extends StatelessWidget {
  final num value;
  final TextStyle? style;
  const AnimatedMoney(this.value, {super.key, this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: const Duration(milliseconds: 550),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text(formatMoney(v.round()), style: style),
  );
}
