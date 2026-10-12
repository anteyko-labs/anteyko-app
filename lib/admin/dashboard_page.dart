import 'dart:math';

import 'package:flutter/material.dart';

import '../core/features.dart';
import '../core/format.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';
import 'orders_page.dart';

/// Обзор: аналитика продаж (Премиум) или короткая сводка с предложением включить.
class DashboardPage extends StatefulWidget {
  final VoidCallback? onOpenSettings;
  const DashboardPage({super.key, this.onOpenSettings});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<(List<DbRow>, List<DbRow>, List<DbRow>)>? _future;
  int _days = 30;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<(List<DbRow>, List<DbRow>, List<DbRow>)> _load() {
    final api = AdminScope.of(context);
    return (api.orders(), api.list('products'), api.reviews()).wait;
  }

  Future<void> _reload() async {
    final f = _load();
    setState(() {
      _future = f;
    });
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final scope = AdminSettings.of(context);
    final analytics = scope.on(Feature.analytics);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обзор'),
        actions: [
          IconButton(tooltip: 'Обновить', icon: const Icon(Icons.refresh), onPressed: _reload),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          final (orders, products, reviews) = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  children: analytics
                      ? _analytics(context, orders)
                      : _basic(context, orders, products, reviews, () async {
                          final s = scope.settings;
                          await scope.save(s.copyWith(overrides: {...s.overrides, Feature.analytics: true}));
                        }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _basic(BuildContext context, List<DbRow> orders, List<DbRow> products, List<DbRow> reviews, VoidCallback enable) {
    final scope = AdminSettings.of(context);
    final today = DateTime.now();
    final todayOrders = orders.where((o) => _sameDay(_date(o), today)).length;
    final limit = scope.settings.info.productLimit;
    return [
      _Tiles(
        tiles: [
          if (scope.on(Feature.cart)) _Tile('Заказов сегодня', todayOrders, Icons.receipt_long_outlined),
          if (scope.on(Feature.cart))
            _Tile('Новых заказов', orders.where((o) => o['status'] == 'new').length, Icons.fiber_new_outlined),
          _Tile('Товаров', products.length, Icons.inventory_2_outlined, suffix: limit == null ? null : ' / $limit'),
          if (scope.on(Feature.reviews))
            _Tile('Отзывов на модерации', reviews.where((r) => r['approved'] != true).length, Icons.star_outline),
        ],
      ),
      const SizedBox(height: 20),
      UpsellCard(feature: Feature.analytics, onEnable: enable),
    ];
  }

  List<Widget> _analytics(BuildContext context, List<DbRow> orders) {
    final t = Theme.of(context);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: _days - 1));
    final prevStart = start.subtract(Duration(days: _days));
    final paid = orders.where((o) => o['status'] != 'cancelled').toList();
    final cur = paid.where((o) => !_date(o).isBefore(start)).toList();
    final prev = paid.where((o) => !_date(o).isBefore(prevStart) && _date(o).isBefore(start)).toList();
    num sum(List<DbRow> l) => l.fold<num>(0, (s, o) => s + (o['total'] as num));

    final revenue = sum(cur);
    final prevRevenue = sum(prev);
    final avg = cur.isEmpty ? 0 : revenue / cur.length;
    final prevAvg = prev.isEmpty ? 0 : prevRevenue / prev.length;

    // Выручка по дням.
    final byDay = List<num>.filled(_days, 0);
    for (final o in cur) {
      final d = _date(o);
      final i = DateTime(d.year, d.month, d.day).difference(start).inDays;
      if (i >= 0 && i < _days) byDay[i] += o['total'] as num;
    }

    // Топ товаров по выручке.
    final top = <String, num>{};
    for (final o in cur) {
      for (final l in (o['lines'] as List).cast<Map>()) {
        top.update(
          '${l['title']}',
          (v) => v + (l['price'] as num) * (l['quantity'] as num),
          ifAbsent: () => (l['price'] as num) * (l['quantity'] as num),
        );
      }
    }
    final topList = top.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final statusCounts = <String, int>{};
    for (final o in orders.where((o) => !_date(o).isBefore(start))) {
      statusCounts.update(o['status'] as String, (v) => v + 1, ifAbsent: () => 1);
    }

    return [
      Row(
        children: [
          Expanded(
            child: Text('Продажи', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 дней')),
              ButtonSegment(value: 30, label: Text('30 дней')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _Tiles(
        tiles: [
          _Tile('Выручка', revenue, Icons.payments_outlined, money: true, delta: _delta(revenue, prevRevenue)),
          _Tile('Заказы', cur.length, Icons.receipt_long_outlined, delta: _delta(cur.length, prev.length)),
          _Tile('Средний чек', avg, Icons.shopping_basket_outlined, money: true, delta: _delta(avg, prevAvg)),
          _Tile('Новых, ждут ответа', orders.where((o) => o['status'] == 'new').length, Icons.notifications_active_outlined),
        ],
      ),
      const SizedBox(height: 16),
      _Panel(
        title: 'Выручка по дням',
        subtitle: 'за последние $_days дней, без отменённых заказов',
        child: SizedBox(
          height: 220,
          child: _RevenueChart(values: byDay, start: start, key: ValueKey(_days)),
        ),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, c) {
          final topPanel = _Panel(
            title: 'Топ товаров',
            subtitle: 'по выручке',
            child: Column(
              children: [
                if (topList.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Пока нет продаж')),
                for (final (i, e) in topList.take(5).indexed)
                  _TopRow(rank: i + 1, title: e.key, value: e.value, max: topList.first.value),
              ],
            ),
          );
          final statusPanel = _Panel(
            title: 'Статусы заказов',
            subtitle: 'за период',
            child: _StatusBar(counts: statusCounts),
          );
          if (c.maxWidth < 760) return Column(spacing: 16, children: [topPanel, statusPanel]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Expanded(flex: 3, child: topPanel),
              Expanded(flex: 2, child: statusPanel),
            ],
          );
        },
      ),
    ];
  }

  static DateTime _date(DbRow o) => DateTime.parse(o['created_at'] as String).toLocal();
  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  static double? _delta(num cur, num prev) => prev == 0 ? null : (cur - prev) / prev * 100;
}

class _Tile {
  final String label;
  final num value;
  final IconData icon;
  final bool money;
  final double? delta;
  final String? suffix;
  const _Tile(this.label, this.value, this.icon, {this.money = false, this.delta, this.suffix});
}

class _Tiles extends StatelessWidget {
  final List<_Tile> tiles;
  const _Tiles({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 900 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (i, tile) in tiles.indexed)
              SizedBox(
                width: w,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 500 + i * 120),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Opacity(
                    opacity: v,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: t.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(tile.icon, size: 18, color: t.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tile.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${tile.money ? formatMoney((tile.value * v).round()) : (tile.value * v).round()}${tile.suffix ?? ''}',
                              style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (tile.delta != null)
                            Row(
                              children: [
                                Icon(
                                  tile.delta! >= 0 ? Icons.trending_up : Icons.trending_down,
                                  size: 16,
                                  color: tile.delta! >= 0 ? const Color(0xFF15803D) : t.colorScheme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${tile.delta! >= 0 ? '+' : ''}${tile.delta!.toStringAsFixed(0)}% к прошлому периоду',
                                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            )
                          else
                            const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Panel({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(color: t.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(subtitle, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Столбики выручки: один цвет, скруглённый верх, подсказка по нажатию/наведению.
class _RevenueChart extends StatefulWidget {
  final List<num> values;
  final DateTime start;
  const _RevenueChart({super.key, required this.values, required this.start});

  @override
  State<_RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<_RevenueChart> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  int? _hover;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int? _index(Offset p, Size size) {
    final n = widget.values.length;
    final i = (p.dx / size.width * n).floor();
    return i >= 0 && i < n ? i : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final maxV = widget.values.fold<num>(0, max);
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight - 22);
        final i = _hover;
        return MouseRegion(
          onHover: (e) => setState(() => _hover = _index(e.localPosition, size)),
          onExit: (_) => setState(() => _hover = null),
          child: GestureDetector(
            onTapDown: (e) => setState(() => _hover = _index(e.localPosition, size)),
            onPanUpdate: (e) => setState(() => _hover = _index(e.localPosition, size)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, _) => CustomPaint(
                    size: Size(c.maxWidth, c.maxHeight),
                    painter: _BarsPainter(
                      values: widget.values,
                      max: maxV,
                      progress: Curves.easeOutCubic.transform(_c.value),
                      color: t.colorScheme.primary,
                      muted: t.colorScheme.primary.withValues(alpha: 0.35),
                      grid: t.colorScheme.outlineVariant.withValues(alpha: 0.6),
                      label: t.textTheme.labelSmall!.copyWith(color: t.colorScheme.onSurfaceVariant),
                      start: widget.start,
                      highlight: i,
                    ),
                  ),
                ),
                if (i != null)
                  Positioned(
                    left: ((i + 0.5) / widget.values.length * size.width - 70).clamp(0, size.width - 140),
                    top: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: t.colorScheme.inverseSurface, borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dayLabel(widget.start.add(Duration(days: i))),
                              style: TextStyle(color: t.colorScheme.onInverseSurface.withValues(alpha: 0.7), fontSize: 12),
                            ),
                            Text(
                              formatMoney(widget.values[i].round()),
                              style: TextStyle(color: t.colorScheme.onInverseSurface, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const _months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
String _dayLabel(DateTime d) => '${d.day} ${_months[d.month - 1]}';

class _BarsPainter extends CustomPainter {
  final List<num> values;
  final num max;
  final double progress;
  final Color color;
  final Color muted;
  final Color grid;
  final TextStyle label;
  final DateTime start;
  final int? highlight;

  _BarsPainter({
    required this.values,
    required this.max,
    required this.progress,
    required this.color,
    required this.muted,
    required this.grid,
    required this.label,
    required this.start,
    required this.highlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 22.0;
    final h = size.height - bottomPad;
    final n = values.length;
    final slot = size.width / n;
    final barW = (slot * 0.62).clamp(2.0, 28.0);

    // Сетка: 3 тонкие линии, ненавязчиво.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = h - h * k / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < n; i++) {
      final v = max == 0 ? 0.0 : values[i] / max;
      final bh = (h - 4) * v * progress;
      if (bh <= 0) continue;
      final x = slot * i + (slot - barW) / 2;
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, h - bh, barW, bh),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = highlight == null || highlight == i ? color : muted);
    }

    // Подписи дат: первая, середина, последняя.
    for (final i in {0, n ~/ 2, n - 1}) {
      final tp = TextPainter(
        text: TextSpan(
          text: _dayLabel(start.add(Duration(days: i))),
          style: label,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (slot * (i + 0.5) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, h + 6));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.progress != progress || old.highlight != highlight || old.values != values;
}

class _TopRow extends StatelessWidget {
  final int rank;
  final String title;
  final num value;
  final num max;
  const _TopRow({required this.rank, required this.title, required this.value, required this.max});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('$rank', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(formatMoney(value.round()), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: max == 0 ? 0 : value / max),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: t.colorScheme.primary,
                      backgroundColor: t.colorScheme.surfaceContainerHighest,
                    ),
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

/// Доли статусов: полоса из сегментов с зазорами + подписи (не только цветом).
class _StatusBar extends StatelessWidget {
  final Map<String, int> counts;
  const _StatusBar({required this.counts});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const Text('Нет заказов за период');
    final order = orderStatuses.keys.where(counts.containsKey).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              spacing: 2,
              children: [
                for (final s in order)
                  Expanded(
                    flex: counts[s]!,
                    child: ColoredBox(color: statusColor(context, s)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final s in order)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: statusColor(context, s), borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(orderStatuses[s]!)),
                Text('${counts[s]}', style: const TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${(counts[s]! / total * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
