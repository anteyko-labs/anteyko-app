import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../glass.dart';
import '../motion.dart';
import '../system_prefs.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';
import 'catalog_screen.dart';
import 'favorites_screen.dart';
import 'home_layouts.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import '../../core/features.dart';

enum ShellTab { home, catalog, favorites, cart, more }

/// Переключение вкладок из любого экрана: ShellNav.go(context, ShellTab.catalog).
class ShellNav extends InheritedWidget {
  final ValueChanged<ShellTab> onGo;

  /// Центр иконки корзины в глобальных координатах — куда «летит» товар.
  final Offset? Function() cartTarget;
  const ShellNav({super.key, required this.onGo, required this.cartTarget, required super.child});

  static void go(BuildContext context, ShellTab tab) => context.dependOnInheritedWidgetOfExactType<ShellNav>()?.onGo(tab);

  static Offset? cartPosition(BuildContext context) => context.getInheritedWidgetOfExactType<ShellNav>()?.cartTarget();

  @override
  bool updateShouldNotify(ShellNav old) => false;
}

/// Нижняя навигация. Вкладки собираются из brand.features, подписи — из brand.style.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  ShellTab _tab = ShellTab.home;
  final _navKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);

    if (state.catalog == null) {
      return Scaffold(
        body: state.error != null
            ? EmptyState(
                icon: Icons.cloud_off,
                title: S.loadError,
                hint: '${state.error}',
                action: FilledButton.tonal(onPressed: state.loadCatalog, child: Text(S.retry)),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final (catalogLabel, catalogIcon) = switch (brand.style) {
      UiStyle.menu => ('Меню', Icons.restaurant_menu),
      UiStyle.services => ('Услуги', Icons.spa_outlined),
      UiStyle.showroom => ('Коллекции', Icons.view_quilt_outlined),
      _ => (S.catalog, Icons.grid_view_rounded),
    };

    final tabs = <_Tab>[
      _Tab(
        ShellTab.home,
        Icons.home_outlined,
        Icons.home_rounded,
        S.home,
        const Scaffold(body: SafeArea(bottom: false, child: HomeScreen())),
      ),
      _Tab(ShellTab.catalog, catalogIcon, catalogIcon, catalogLabel, const CatalogScreen()),
      if (has(Feature.favorites))
        _Tab(ShellTab.favorites, Icons.favorite_border, Icons.favorite, S.favorites, const FavoritesScreen()),
      if (has(Feature.cart))
        _Tab(
          ShellTab.cart,
          Icons.shopping_bag_outlined,
          Icons.shopping_bag,
          S.cart,
          CartScreen(onBrowse: () => setState(() => _tab = ShellTab.catalog)),
          badge: state.cartCount,
        ),
      _Tab(ShellTab.more, Icons.menu, Icons.menu, S.more, const MoreScreen()),
    ];
    var index = tabs.indexWhere((t) => t.id == _tab);
    if (index < 0) index = 0;

    final showCartBar =
        has(Feature.cart) &&
        (brand.style == UiStyle.menu || brand.style == UiStyle.grocery) &&
        _tab != ShellTab.cart &&
        state.cartCount > 0;

    final cartIndex = tabs.indexWhere((t) => t.id == ShellTab.cart);
    return ShellNav(
      onGo: (t) => setState(() => _tab = t),
      cartTarget: () {
        final box = _navKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || cartIndex < 0) return null;
        final w = box.size.width / tabs.length;
        return box.localToGlobal(Offset(w * (cartIndex + 0.5), 28));
      },
      child: Scaffold(
        // Контент уходит под стеклянное меню и просвечивает сквозь него.
        extendBody: true,
        body: Builder(
          builder: (context) {
            final bottom = MediaQuery.paddingOf(context).bottom;
            return Stack(
              children: [
                _FadeIndexedStack(index: index, children: [for (final t in tabs) t.screen]),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12 + bottom,
                  child: AnimatedSlide(
                    offset: showCartBar ? Offset.zero : const Offset(0, 1.6),
                    duration: motionMedium,
                    curve: showCartBar ? Curves.easeOutBack : Curves.easeInCubic,
                    child: AnimatedOpacity(
                      opacity: showCartBar ? 1 : 0,
                      duration: motionFast,
                      child: IgnorePointer(
                        ignoring: !showCartBar,
                        child: _CartBar(onTap: () => setState(() => _tab = ShellTab.cart)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: Glass(
          key: _navKey,
          opacity: 0.72,
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _tab = tabs[i].id),
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: _badged(t, Icon(t.icon)),
                  selectedIcon: _badged(t, Icon(t.selectedIcon)),
                  label: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badged(_Tab t, Widget icon) => BounceOnChange(
    value: t.badge,
    child: Badge(isLabelVisible: t.badge > 0, label: Text('${t.badge}'), child: icon),
  );
}

/// Вкладки с плавной сменой (затухание + лёгкий подъём), состояние каждой сохраняется.
class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _FadeIndexedStack({required this.index, required this.children});

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: motionMedium, value: 1);

  @override
  void didUpdateWidget(_FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !SystemLook.reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final v = motionCurve.transform(_c.value);
      return Opacity(
        opacity: 0.2 + 0.8 * v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
      );
    },
    child: IndexedStack(index: widget.index, children: widget.children),
  );
}

class _CartBar extends StatelessWidget {
  final VoidCallback onTap;
  const _CartBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: Glass(
        tint: scheme.primary,
        opacity: 0.86,
        border: false,
        borderRadius: BorderRadius.circular(brand.cornerRadius.clamp(8, 28)),
        shadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  BounceOnChange(
                    value: state.cartCount,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: scheme.onPrimary,
                      child: Text(
                        '${state.cartCount}',
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      S.cart,
                      style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  AnimatedMoney(
                    state.subtotal,
                    style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, color: scheme.onPrimary, size: 18),
                ],
              ),
              if (brand.style == UiStyle.grocery && brand.checkout.freeDeliveryFrom != null) ...[
                const SizedBox(height: 10),
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: scheme.copyWith(
                      primary: scheme.onPrimary,
                      surfaceContainerHighest: scheme.onPrimary.withValues(alpha: 0.25),
                    ),
                    textTheme: Theme.of(context).textTheme.apply(bodyColor: scheme.onPrimary),
                  ),
                  child: const FreeDeliveryProgress(compact: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final ShellTab id;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;
  final int badge;
  const _Tab(this.id, this.icon, this.selectedIcon, this.label, this.screen, {this.badge = 0});
}
