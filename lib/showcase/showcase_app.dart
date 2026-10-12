import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../brand/brand_config.dart';
import '../core/app_state.dart';
import '../admin/admin_app.dart';
import '../admin/local_admin_api.dart';
import '../core/features.dart';
import '../core/local_store.dart';
import '../core/order_service.dart';
import '../ui/glass.dart';
import '../ui/motion.dart';
import '../ui/system_prefs.dart';
import '../ui/store_app.dart';
import 'demos.dart';

/// Витрина студии: выбор типа приложения → живое демо с его брендом,
/// переключение тарифа на лету и админка демо.
class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  DemoTemplate? _current;
  bool _admin = false;

  /// Состояние каждого демо живёт, пока открыта витрина: корзина не теряется при переключении.
  final _states = <String, AppState>{};

  Future<void> _open(DemoTemplate t, {Plan? plan}) async {
    setBrand(t.brand);
    final store = localStoreFor(t.brand);
    if (plan != null) await _applyPlan(store, plan);
    _states.putIfAbsent(t.brand.id, () => AppState(backend: store)..init());
    setState(() {
      _current = t;
      _admin = false;
    });
  }

  /// Тариф из витрины: ставим тариф и снимаем ручные переключатели — чтобы было видно «чистый» тариф.
  Future<void> _applyPlan(LocalStore store, Plan plan) async {
    await store.ensure();
    store.settings = store.settings.copyWith(plan: plan, overrides: {});
    await store.save();
  }

  // Бренд не сбрасываем: уходящее демо ещё анимируется и должно остаться в своём стиле.
  void _close() => setState(() {
    _current = null;
    _admin = false;
  });

  @override
  Widget build(BuildContext context) {
    final t = _current;
    final Widget child;
    if (t == null) {
      child = _ShowcaseHome(
        key: const ValueKey('home'),
        onOpen: (d, {plan}) => _open(d, plan: plan),
      );
    } else {
      final store = localStoreFor(t.brand);
      child = _admin
          ? AdminApp(
              key: ValueKey('admin-${t.brand.id}'),
              api: LocalAdminApi(store),
              onExit: () => setState(() => _admin = false),
            )
          : _DemoFrame(
              key: ValueKey(t.brand.id),
              template: t,
              store: store,
              onClose: _close,
              onAdmin: () => setState(() => _admin = true),
              onPlan: (p) => _applyPlan(store, p),
              child: StoreApp(state: _states[t.brand.id]!),
            );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: motionCurve,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
//  Рамка вокруг демо: «← · тариф ▾ · админка · заказать».
// ---------------------------------------------------------------------------

class _DemoFrame extends StatelessWidget {
  final DemoTemplate template;
  final LocalStore store;
  final VoidCallback onClose;
  final VoidCallback onAdmin;
  final ValueChanged<Plan> onPlan;
  final Widget child;
  const _DemoFrame({
    super.key,
    required this.template,
    required this.store,
    required this.onClose,
    required this.onAdmin,
    required this.onPlan,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wide = mq.size.width > 560;
    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
    // Своё MaterialApp у рамки: выпадающему меню тарифа нужны локализация и слой поверх экрана.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: _body, colorSchemeSeed: _accent),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Material(
        color: _ink,
        child: Column(
          children: [
            Material(
              color: _ink,
              child: Padding(
                padding: EdgeInsets.only(top: mq.padding.top),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Все демо',
                        color: Colors.white,
                        onPressed: onClose,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      if (wide) Text(template.title, style: white.copyWith(color: Colors.white70)),
                      const Spacer(),
                      ListenableBuilder(
                        listenable: store,
                        builder: (context, _) => _PlanSwitcher(plan: store.settings.plan, onPlan: onPlan),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: onAdmin,
                        icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                        label: const Text('Админка'),
                      ),
                      if (wide)
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: () => openLink('https://t.me/${studio.telegram}'),
                          child: const Text('Заказать'),
                        ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// «● Премиум ▾» — переключение тарифа демо на лету.
class _PlanSwitcher extends StatelessWidget {
  final Plan plan;
  final ValueChanged<Plan> onPlan;
  const _PlanSwitcher({required this.plan, required this.onPlan});

  @override
  Widget build(BuildContext context) {
    final color = planColor(plan);
    return PopupMenuButton<Plan>(
      tooltip: 'Тариф демо',
      initialValue: plan,
      onSelected: onPlan,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final p in Plan.values)
          PopupMenuItem(
            value: p,
            child: SizedBox(
              width: 240,
              child: Row(
                children: [
                  Icon(planInfo[p]!.icon, color: planColor(p)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(planInfo[p]!.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(planInfo[p]!.tagline, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  if (p == plan) Icon(Icons.check, color: planColor(p)),
                ],
              ),
            ),
          ),
      ],
      child: AnimatedContainer(
        duration: motionMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(planInfo[plan]!.icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: motionFast,
              child: Text(
                planInfo[plan]!.title,
                key: ValueKey(plan),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Главная витрины.
// ---------------------------------------------------------------------------

const _ink = Color(0xFF0E0F13);
const _accent = Color(0xFF5B5BF6);
const _display = 'Unbounded';
const _body = 'Manrope';

typedef OpenDemo = void Function(DemoTemplate demo, {Plan? plan});

class _ShowcaseHome extends StatefulWidget {
  final OpenDemo onOpen;
  const _ShowcaseHome({super.key, required this.onOpen});

  @override
  State<_ShowcaseHome> createState() => _ShowcaseHomeState();
}

class _ShowcaseHomeState extends State<_ShowcaseHome> {
  final _scroll = ScrollController();
  bool _header = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 280;
      if (show != _header) setState(() => _header = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  OpenDemo get onOpen => widget.onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: _accent, surface: const Color(0xFFF6F6F8));
    return MaterialApp(
      title: '${studio.name} — демо приложений',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: scheme.surface, fontFamily: _body),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        syncPageColor(const Color(0xFFF6F6F8));
        return SystemLook(child: child!);
      },
      home: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              slivers: [
                const SliverToBoxAdapter(child: _Hero()),
                SliverToBoxAdapter(
                  child: _Centered(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
                          final w = (c.maxWidth - (cols - 1) * 16) / cols;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final (i, d) in demos.indexed)
                                SizedBox(
                                  width: w,
                                  child: FadeSlideIn(
                                    index: i + 2,
                                    offset: const Offset(0, 40),
                                    child: _DemoCard(template: d, onOpen: () => onOpen(d)),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _Pricing(onTry: (p) => onOpen(demos.first, plan: p)),
                ),
                const SliverToBoxAdapter(child: _Included()),
                const SliverToBoxAdapter(child: _Cta()),
              ],
            ),
            // Стеклянная шапка появляется после прокрутки hero.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                offset: _header ? Offset.zero : const Offset(0, -1.2),
                duration: motionMedium,
                curve: motionCurve,
                child: const _StickyHeader(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyHeader extends StatelessWidget {
  const _StickyHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Glass(
      tint: const Color(0xFFF6F6F8),
      opacity: 0.7,
      border: false,
      shadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20)],
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, top + 10, 16, 10),
        child: _Centered(
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: const Text(
                  'A',
                  style: TextStyle(fontFamily: _display, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  studio.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: _display, fontWeight: FontWeight.w700, fontSize: 17, color: _ink),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _ink, minimumSize: const Size(0, 40)),
                onPressed: () => openLink('https://t.me/${studio.telegram}'),
                child: const Text('Обсудить проект'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: child),
  );
}

/// Шапка: «дышащий» градиентный фон и сменяющееся слово «для кафе / магазина / …».
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  static const _words = ['магазина', 'кафе', 'цветочного', 'супермаркета', 'шоурума', 'салона'];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (ambientAnimations) {
      _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) => setState(() => _i = (_i + 1) % _words.length));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final wide = MediaQuery.sizeOf(context).width > 700;
    final color = demos[_i % demos.length].brand.primaryColor;
    final titleStyle = t.displaySmall?.copyWith(
      fontFamily: _display,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      height: 1.08,
      fontSize: wide ? 52 : 34,
      color: _ink,
    );

    return Stack(
      children: [
        // Цветные пятна в цветах демо, медленно плавают.
        Positioned.fill(
          child: Breathing(
            period: const Duration(seconds: 9),
            builder: (context, v) => CustomPaint(painter: _BlobsPainter(v)),
          ),
        ),
        _Centered(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, top + 24, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(11)),
                        alignment: Alignment.center,
                        child: const Text(
                          'A',
                          style: TextStyle(fontFamily: _display, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        studio.name,
                        style: t.titleLarge?.copyWith(fontFamily: _display, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      ),
                      const Spacer(),
                      if (wide) const _Pill(text: 'Бишкек · Дубай'),
                    ],
                  ),
                ),
                SizedBox(height: wide ? 56 : 36),
                FadeSlideIn(index: 1, child: Text('Мобильное приложение для', style: titleStyle)),
                FadeSlideIn(
                  index: 2,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    // Новое слово приезжает снизу, старое уезжает вверх — как на табло.
                    transitionBuilder: (child, a) {
                      final incoming = child.key == ValueKey(_i);
                      return ClipRect(
                        child: FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: Offset(0, incoming ? 0.6 : -0.6), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        ),
                      );
                    },
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                    child: Text(
                      _words[_i],
                      key: ValueKey(_i),
                      style: titleStyle?.copyWith(color: color),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  index: 3,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      'Откройте живое демо — в нём всё работает: каталог, корзина, запись, оформление заказа. '
                      'Сделаем такое же под ваш бренд, товары и процессы.',
                      style: t.bodyLarge?.copyWith(color: Colors.black54, height: 1.5, fontSize: wide ? 18 : 16),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FadeSlideIn(
                  index: 4,
                  child: const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(text: '6 готовых интерфейсов', icon: Icons.auto_awesome),
                      _Pill(text: 'iOS + Android + Web', icon: Icons.devices),
                      _Pill(text: 'Запуск от 2 недель', icon: Icons.rocket_launch_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlobsPainter extends CustomPainter {
  final double t;
  _BlobsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = [
      (demos[0].brand.primaryColor, Offset(size.width * (0.85 - 0.05 * t), size.height * (0.15 + 0.05 * t)), size.width * 0.35),
      (demos[1].brand.primaryColor, Offset(size.width * (0.65 + 0.06 * t), size.height * (0.75 - 0.05 * t)), size.width * 0.28),
      (demos[5].brand.primaryColor, Offset(size.width * (0.1 + 0.05 * t), size.height * (0.85 - 0.1 * t)), size.width * 0.3),
    ];
    for (final (color, center, r) in blobs) {
      final radius = r.clamp(120, 420).toDouble();
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobsPainter old) => old.t != t;
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _Pill({required this.text, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 15, color: _accent), const SizedBox(width: 6)],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
          ),
        ),
      ],
    ),
  );
}

class _DemoCard extends StatefulWidget {
  final DemoTemplate template;
  final VoidCallback onOpen;
  const _DemoCard({required this.template, required this.onOpen});

  @override
  State<_DemoCard> createState() => _DemoCardState();
}

class _DemoCardState extends State<_DemoCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final b = template.brand;
    final t = Theme.of(context).textTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Pressable(
        onTap: widget.onOpen,
        scale: 0.97,
        child: AnimatedContainer(
          duration: motionMedium,
          curve: motionCurve,
          transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: b.primaryColor.withValues(alpha: _hover ? 0.28 : 0.08),
                blurRadius: _hover ? 36 : 18,
                offset: Offset(0, _hover ? 18 : 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 170,
                child: _MiniPreview(template: template, hover: _hover),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(template.icon, size: 20, color: b.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            template.title,
                            style: t.titleMedium?.copyWith(fontFamily: _display, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      template.pitch,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final h in template.highlights)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: b.primaryColor.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              h,
                              style: TextStyle(fontSize: 12, color: b.primaryColor, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Открыть демо',
                          style: TextStyle(color: b.primaryColor, fontWeight: FontWeight.w800),
                        ),
                        AnimatedPadding(
                          duration: motionMedium,
                          curve: motionCurve,
                          padding: EdgeInsets.only(left: _hover ? 10 : 4),
                          child: Icon(Icons.arrow_forward, size: 18, color: b.primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Схематичный экран демо: у каждого стиля своя мини-раскладка, телефон «парит».
class _MiniPreview extends StatelessWidget {
  final DemoTemplate template;
  final bool hover;
  const _MiniPreview({required this.template, required this.hover});

  @override
  Widget build(BuildContext context) {
    final b = template.brand;
    final c = b.primaryColor;
    final dark = b.themeMode == ThemeMode.dark;
    final screen = dark ? const Color(0xFF1A1512) : Colors.white;
    final r = (b.cornerRadius / 3).clamp(1.0, 8.0);
    Widget block(double a, {double? h, double? w, double radius = -1}) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: c.withValues(alpha: a),
        borderRadius: BorderRadius.circular(radius < 0 ? r : radius),
      ),
    );
    Widget row(List<Widget> children) => Expanded(
      child: Row(spacing: 4, children: [for (final w in children) Expanded(child: w)]),
    );

    final body = switch (b.style) {
      UiStyle.menu => Column(
        spacing: 5,
        children: [
          Row(
            spacing: 4,
            children: [
              block(1, h: 9, w: 26, radius: 6),
              block(0.25, h: 9, w: 22, radius: 6),
              block(0.25, h: 9, w: 18, radius: 6),
            ],
          ),
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Row(
                spacing: 5,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 3,
                      children: [block(0.5, h: 5, w: 40), block(0.2, h: 4, w: 30)],
                    ),
                  ),
                  AspectRatio(aspectRatio: 1, child: block(0.3)),
                ],
              ),
            ),
        ],
      ),
      UiStyle.grocery => Column(
        spacing: 4,
        children: [
          block(0.9, h: 18),
          row([block(0.2), block(0.3), block(0.2)]),
          row([block(0.3), block(0.2), block(0.3)]),
        ],
      ),
      UiStyle.showroom => Column(
        spacing: 5,
        children: [
          Expanded(flex: 3, child: block(0.55)),
          for (var i = 0; i < 3; i++) Container(height: 1, color: c.withValues(alpha: 0.3)),
        ],
      ),
      UiStyle.services => Column(
        spacing: 5,
        children: [
          block(0.9, h: 22, radius: 8),
          Row(
            spacing: 4,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.3)),
                ),
            ],
          ),
          for (var i = 0; i < 2; i++) block(0.15, h: 16, radius: 6),
        ],
      ),
      UiStyle.boutique => Column(
        spacing: 4,
        children: [
          Expanded(flex: 2, child: block(0.8, radius: 10)),
          row([block(0.25, radius: 10), block(0.18, radius: 10)]),
        ],
      ),
      UiStyle.shop => Column(
        spacing: 4,
        children: [
          block(1, h: 26),
          row([block(0.25), block(0.15)]),
          row([block(0.12), block(0.22)]),
        ],
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withValues(alpha: 0.18), c.withValues(alpha: 0.04)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(left: 20, top: 18, child: Icon(template.icon, color: c.withValues(alpha: 0.6), size: 28)),
          Positioned(
            left: 20,
            bottom: 18,
            right: 150,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                b.appName,
                style: TextStyle(
                  fontFamily: b.headingFont ?? b.fontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          Positioned(
            right: 22,
            top: 20,
            bottom: -40,
            width: 118,
            child: Breathing(
              period: Duration(milliseconds: 3200 + template.title.length * 40),
              builder: (_, v) => AnimatedRotation(
                turns: hover ? -0.012 : 0,
                duration: motionMedium,
                child: Transform.translate(
                  offset: Offset(0, -4 * v + (hover ? -8 : 0)),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    decoration: BoxDecoration(
                      color: screen,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 3),
                      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.appName,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontFamily: b.headingFont ?? b.fontFamily,
                            color: c,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Included extends StatelessWidget {
  const _Included();

  static const _items = [
    (Icons.phone_iphone, 'iOS и Android', 'Одно приложение для двух платформ, публикуем в App Store и Google Play.'),
    (Icons.dashboard_customize_outlined, 'Админ-панель', 'Товары, цены, баннеры и заказы меняете сами — без программиста.'),
    (Icons.palette_outlined, 'Ваш бренд', 'Логотип, цвета, шрифты и тексты под ваш фирменный стиль.'),
    (Icons.notifications_active_outlined, 'Заказы сразу к вам', 'В админку, WhatsApp, Telegram или вашу CRM.'),
    (Icons.speed, 'Запуск за 2–4 недели', 'Готовая основа — платите за адаптацию, а не за разработку с нуля.'),
    (Icons.support_agent, 'Поддержка', 'Обновления, доработки и помощь после запуска.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Что входит',
              style: t.headlineSmall?.copyWith(fontFamily: _display, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 760 ? 3 : (c.maxWidth > 480 ? 2 : 1);
                final w = (c.maxWidth - (cols - 1) * 16) / cols;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final (n, i) in _items.indexed)
                      FadeSlideIn(
                        index: n,
                        child: Container(
                          width: w,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(i.$1, color: _accent, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(i.$2, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 3),
                                    Text(i.$3, style: t.bodyMedium?.copyWith(color: Colors.black54, height: 1.4)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return _Centered(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 40, 16, 24 + bottom),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: _ink)),
              Positioned.fill(
                child: Breathing(
                  period: const Duration(seconds: 8),
                  builder: (_, v) => CustomPaint(painter: _BlobsPainter(1 - v)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Нужно такое же приложение?',
                      style: t.headlineSmall?.copyWith(
                        fontFamily: _display,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Расскажите о бизнесе — покажем, как будет выглядеть ваше приложение, и назовём сроки.',
                      style: t.bodyLarge?.copyWith(color: Colors.white70, height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _ink,
                            minimumSize: const Size(0, 52),
                          ),
                          onPressed: () => openLink('https://t.me/${studio.telegram}'),
                          icon: const Icon(Icons.send),
                          label: const Text('Написать в Telegram', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            minimumSize: const Size(0, 52),
                          ),
                          onPressed: () => openLink('tel:${studio.phone.replaceAll(' ', '')}'),
                          icon: const Icon(Icons.call),
                          label: Text(studio.phone),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Тарифы
// ---------------------------------------------------------------------------

class _Pricing extends StatefulWidget {
  final ValueChanged<Plan> onTry;
  const _Pricing({required this.onTry});

  @override
  State<_Pricing> createState() => _PricingState();
}

class _PricingState extends State<_Pricing> {
  bool _compare = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Тарифы',
              style: t.headlineMedium?.copyWith(fontFamily: _display, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Начните с простого и подключайте функции по мере роста — без переделки приложения. '
              'Тариф и отдельные функции включаются в админке одной кнопкой.',
              style: t.bodyLarge?.copyWith(color: Colors.black54, height: 1.45),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 760;
                final cards = [
                  for (final (i, p) in Plan.values.indexed)
                    FadeSlideIn(
                      index: i,
                      child: _PlanCard(plan: p, fill: !narrow, onTry: () => widget.onTry(p)),
                    ),
                ];
                if (narrow) return Column(spacing: 16, children: cards);
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [for (final c in cards) Expanded(child: c)],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _compare = !_compare),
                icon: AnimatedRotation(turns: _compare ? 0.5 : 0, duration: motionMedium, child: const Icon(Icons.expand_more)),
                label: Text(_compare ? 'Скрыть сравнение' : 'Сравнить все функции'),
              ),
            ),
            AnimatedSize(
              duration: motionMedium,
              curve: motionCurve,
              alignment: Alignment.topCenter,
              child: _compare ? const _CompareTable() : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatefulWidget {
  final Plan plan;
  final VoidCallback onTry;

  /// В ряду карточки одной высоты — кнопка прижимается к низу.
  final bool fill;
  const _PlanCard({required this.plan, required this.onTry, this.fill = false});

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final info = planInfo[p]!;
    final popular = p == Plan.business;
    final dark = popular;
    final color = planColor(p);
    final fg = dark ? Colors.white : _ink;
    final muted = dark ? Colors.white70 : Colors.black54;
    final (price, note) = planPrices[p]!;
    final t = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: motionMedium,
        curve: motionCurve,
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: dark ? _ink : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: popular ? color : Colors.black.withValues(alpha: 0.06), width: popular ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: (popular ? color : Colors.black).withValues(alpha: _hover ? 0.22 : (popular ? 0.18 : 0.05)),
              blurRadius: _hover ? 36 : 24,
              offset: Offset(0, _hover ? 18 : 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                  child: Icon(info.icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  info.title,
                  style: t.titleLarge?.copyWith(fontFamily: _display, fontWeight: FontWeight.w700, color: fg),
                ),
                const Spacer(),
                if (popular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                    child: const Text(
                      'Популярный',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(info.tagline, style: t.bodyMedium?.copyWith(color: muted, height: 1.35)),
            const SizedBox(height: 18),
            Text(
              price,
              style: t.displaySmall?.copyWith(fontFamily: _display, fontWeight: FontWeight.w700, color: fg, letterSpacing: -1),
            ),
            Text(note, style: t.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: 18),
            for (final h in planHighlights[p]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(h, style: TextStyle(color: fg, height: 1.3)),
                    ),
                  ],
                ),
              ),
            if (widget.fill) const Spacer(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: popular
                  ? FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size(0, 50)),
                      onPressed: widget.onTry,
                      child: const Text('Попробовать в демо', style: TextStyle(fontWeight: FontWeight.w800)),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: _ink, minimumSize: const Size(0, 50)),
                      onPressed: widget.onTry,
                      child: const Text('Попробовать в демо', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Полная таблица: функция × тариф.
class _CompareTable extends StatelessWidget {
  const _CompareTable();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget cell(Widget child) => SizedBox(width: 74, child: Center(child: child));
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                for (final p in Plan.values)
                  cell(
                    Text(
                      planInfo[p]!.title,
                      style: TextStyle(fontWeight: FontWeight.w800, color: planColor(p), fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          for (final g in FeatureGroup.values) ...[
            Container(
              width: double.infinity,
              color: const Color(0xFFF6F6F8),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Text(featureGroupTitle[g]!, style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final f in Feature.values.where((f) => featureInfo[f]!.group == g))
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(featureInfo[f]!.icon, size: 18, color: Colors.black45),
                    const SizedBox(width: 10),
                    Expanded(child: Text(featureInfo[f]!.title)),
                    for (final p in Plan.values)
                      cell(
                        featureInfo[f]!.plan.index <= p.index
                            ? Icon(Icons.check_rounded, color: planColor(p))
                            : const Text('—', style: TextStyle(color: Colors.black26)),
                      ),
                  ],
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.black45),
                const SizedBox(width: 10),
                const Expanded(child: Text('Товаров в каталоге')),
                for (final p in Plan.values)
                  cell(
                    Text(
                      planInfo[p]!.productLimit == null ? '∞' : 'до ${planInfo[p]!.productLimit}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
