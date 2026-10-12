import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../brand/brand_config.dart';
import '../core/features.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';
import 'categories_page.dart';
import 'dashboard_page.dart';
import 'marketing_pages.dart';
import 'settings_page.dart';
import 'orders_page.dart';
import 'products_page.dart';

/// Веб-админка. Открывается по адресу приложения + /#/admin.
class AdminApp extends StatelessWidget {
  final AdminApi api;

  /// Кнопка «В приложение» (в витрине — вернуться в демо).
  final VoidCallback? onExit;
  const AdminApp({super.key, required this.api, this.onExit});

  @override
  Widget build(BuildContext context) => AdminScope(
    api: api,
    child: MaterialApp(
      title: '${brand.appName} — админка',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: brand.themeMode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: _ExitScope(onExit: onExit, child: const _AuthGate()),
    ),
  );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<void>? _sub;
  Future<bool>? _isAdmin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final api = AdminScope.of(context);
    _check(api);
    _sub = api.authChanges.listen(
      (_) => setState(() {
        _check(api);
      }),
    );
  }

  void _check(AdminApi api) => _isAdmin = api.email == null ? null : api.isAdmin();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = AdminScope.of(context);
    if (!api.configured) return const _NotConfigured();
    if (api.email == null) return const _LoginPage();
    return FutureBuilder<bool>(
      future: _isAdmin,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == true) return const AdminShell();
        return Scaffold(
          body: EmptyState(
            icon: Icons.lock_outline,
            title: 'Нет доступа',
            hint: snap.hasError ? '${snap.error}' : '${api.email} не добавлен в таблицу admins.',
            action: FilledButton.tonal(onPressed: api.signOut, child: const Text('Выйти')),
          ),
        );
      },
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: EmptyState(
      icon: Icons.storage_outlined,
      title: 'Сервер не подключён',
      hint:
          'Создайте проект Supabase, выполните supabase/schema.sql и укажите supabaseUrl и supabaseKey '
          'в lib/brand/brand_config.dart. Подробно — в README, раздел «Админка».',
    ),
  );
}

class _LoginPage extends StatefulWidget {
  const _LoginPage();

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AdminScope.of(context).signIn(_email.text, _password.text);
    } catch (e) {
      setState(() => _error = e.toString().contains('Invalid login') ? 'Неверный email или пароль' : '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(size: 30)),
                  const SizedBox(height: 4),
                  Text(
                    'Панель управления',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Пароль'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitScope extends InheritedWidget {
  final VoidCallback? onExit;
  const _ExitScope({required this.onExit, required super.child});

  static VoidCallback? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ExitScope>()?.onExit;

  @override
  bool updateShouldNotify(_ExitScope old) => false;
}

enum _Section { overview, orders, products, categories, banners, promo, reviews, plan }

class _SectionInfo {
  final IconData icon;
  final IconData selected;
  final String title;
  const _SectionInfo(this.icon, this.selected, this.title);
}

const _sections = {
  _Section.overview: _SectionInfo(Icons.space_dashboard_outlined, Icons.space_dashboard, 'Обзор'),
  _Section.orders: _SectionInfo(Icons.receipt_long_outlined, Icons.receipt_long, 'Заказы'),
  _Section.products: _SectionInfo(Icons.inventory_2_outlined, Icons.inventory_2, 'Товары'),
  _Section.categories: _SectionInfo(Icons.category_outlined, Icons.category, 'Категории'),
  _Section.banners: _SectionInfo(Icons.view_carousel_outlined, Icons.view_carousel, 'Баннеры'),
  _Section.promo: _SectionInfo(Icons.confirmation_number_outlined, Icons.confirmation_number, 'Промокоды'),
  _Section.reviews: _SectionInfo(Icons.star_outline, Icons.star, 'Отзывы'),
  _Section.plan: _SectionInfo(Icons.workspace_premium_outlined, Icons.workspace_premium, 'Тариф'),
};

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  _Section _section = _Section.overview;
  AppSettings? _settings;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settings == null && _error == null) _load();
  }

  Future<void> _load() async {
    try {
      final s = await AdminScope.of(context).getSettings();
      if (mounted) setState(() => _settings = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save(AppSettings s) async {
    await AdminScope.of(context).saveSettings(s);
    if (mounted) setState(() => _settings = s);
  }

  Widget _page(_Section s) => switch (s) {
    _Section.overview => DashboardPage(onOpenSettings: () => setState(() => _section = _Section.plan)),
    _Section.orders => const OrdersPage(),
    _Section.products => const ProductsPage(),
    _Section.categories => const CategoriesPage(),
    _Section.banners => const BannersPage(),
    _Section.promo => const PromoCodesPage(),
    _Section.reviews => const ReviewsPage(),
    _Section.plan => const SettingsPage(),
  };

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: EmptyState(icon: Icons.cloud_off, title: 'Не удалось загрузить настройки', hint: '$_error'),
      );
    }
    final settings = _settings;
    if (settings == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    bool on(Feature f) => isEnabledIn(settings, f);
    // Разделы появляются по включённым функциям.
    final sections = [
      _Section.overview,
      if (on(Feature.cart)) _Section.orders,
      _Section.products,
      _Section.categories,
      if (on(Feature.banners) || on(Feature.stories)) _Section.banners,
      if (on(Feature.promoCodes)) _Section.promo,
      if (on(Feature.reviews)) _Section.reviews,
      _Section.plan,
    ];
    if (!sections.contains(_section)) _section = _Section.overview;

    final api = AdminScope.of(context);
    final onExit = _ExitScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final index = sections.indexOf(_section);
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(key: ValueKey(_section), child: _page(_section)),
    );

    final Widget shell;
    if (wide) {
      shell = Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _section = sections[i]),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    const BrandLogo(size: 18),
                    const SizedBox(height: 6),
                    PlanChip(settings.plan, dense: true),
                    if (api.isDemo) ...[const SizedBox(height: 4), const _DemoTag()],
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: onExit != null
                        ? IconButton.filledTonal(tooltip: 'В приложение', icon: const Icon(Icons.phone_iphone), onPressed: onExit)
                        : IconButton(tooltip: 'Выйти (${api.email})', icon: const Icon(Icons.logout), onPressed: api.signOut),
                  ),
                ),
              ),
              destinations: [
                for (final s in sections)
                  NavigationRailDestination(
                    icon: Icon(_sections[s]!.icon),
                    selectedIcon: Icon(_sections[s]!.selected),
                    label: Text(_sections[s]!.title),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      // На телефоне: 4 главных раздела + «Ещё».
      final main = sections.take(sections.contains(_Section.orders) ? 3 : 2).toList();
      final more = sections.where((s) => !main.contains(s)).toList();
      final inMore = more.contains(_section);
      shell = Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: inMore ? main.length : main.indexOf(_section),
          onDestinationSelected: (i) {
            if (i < main.length) {
              setState(() => _section = main[i]);
            } else {
              _openMore(context, more, onExit, api);
            }
          },
          destinations: [
            for (final s in main)
              NavigationDestination(
                icon: Icon(_sections[s]!.icon),
                selectedIcon: Icon(_sections[s]!.selected),
                label: _sections[s]!.title,
              ),
            NavigationDestination(icon: const Icon(Icons.menu), label: inMore ? _sections[_section]!.title : 'Ещё'),
          ],
        ),
      );
    }
    return AdminSettings(settings: settings, save: _save, child: shell);
  }

  void _openMore(BuildContext context, List<_Section> more, VoidCallback? onExit, AdminApi api) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in more)
              ListTile(
                leading: Icon(_sections[s]!.icon),
                title: Text(_sections[s]!.title),
                selected: s == _section,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _section = s);
                },
              ),
            const Divider(),
            if (onExit != null)
              ListTile(
                leading: const Icon(Icons.phone_iphone),
                title: const Text('Вернуться в приложение'),
                onTap: () {
                  Navigator.pop(ctx);
                  onExit();
                },
              )
            else
              ListTile(leading: const Icon(Icons.logout), title: Text('Выйти (${api.email})'), onTap: api.signOut),
          ],
        ),
      ),
    );
  }
}

class _DemoTag extends StatelessWidget {
  const _DemoTag();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Демо-режим: данные хранятся в этом браузере',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(6)),
      child: const Text('демо', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}
