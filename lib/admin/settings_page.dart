import 'package:flutter/material.dart';

import '../core/features.dart';
import 'admin_widgets.dart';

/// «Тариф и функции»: выбор тарифа одной кнопкой + ручные переключатели поверх него.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scope = AdminSettings.of(context);
    final s = scope.settings;
    final api = AdminScope.of(context);
    final changed = s.overrides.entries.where((e) => e.value != s.includedInPlan(e.key)).length;

    Future<void> save(AppSettings next, [String? done]) async {
      try {
        await scope.save(next);
        if (done != null && context.mounted) showDone(context, done);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    void toggle(Feature f, bool v) {
      final o = Map.of(s.overrides);
      // Совпадает с тарифом — ручная настройка не нужна.
      v == s.includedInPlan(f) ? o.remove(f) : o[f] = v;
      save(s.copyWith(overrides: o));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Тариф и функции')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Text(
                'Выберите тариф — функции включатся автоматически. Любую функцию можно включить или выключить вручную.',
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 640;
                  final cards = [
                    for (final p in Plan.values)
                      _PlanCard(
                        plan: p,
                        selected: s.plan == p,
                        onTap: () => save(s.copyWith(plan: p), 'Тариф «${planInfo[p]!.title}» применён'),
                      ),
                  ];
                  return wide
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 12,
                            children: [for (final c in cards) Expanded(child: c)],
                          ),
                        )
                      : Column(spacing: 10, children: cards);
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: changed == 0
                    ? const SizedBox(height: 8)
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Material(
                          color: t.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            leading: const Icon(Icons.tune),
                            title: Text('Изменено вручную: $changed ${_plural(changed)}'),
                            trailing: TextButton(
                              onPressed: () => save(s.copyWith(overrides: {}), 'Функции сброшены к тарифу'),
                              child: const Text('Сбросить к тарифу'),
                            ),
                          ),
                        ),
                      ),
              ),
              for (final g in FeatureGroup.values) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  child: Text(featureGroupTitle[g]!, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, f) in Feature.values.where((f) => featureInfo[f]!.group == g).indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 72),
                        _FeatureTile(feature: f, settings: s, onChanged: (v) => toggle(f, v)),
                      ],
                    ],
                  ),
                ),
              ],
              if (scope.on(Feature.loyalty)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text('Бонусная программа', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      children: [
                        _SliderRow(
                          label: 'Кэшбэк бонусами',
                          value: s.loyaltyPercent,
                          min: 1,
                          max: 20,
                          suffix: '% от суммы заказа',
                          onDone: (v) => save(s.copyWith(loyaltyPercent: v), 'Сохранено'),
                        ),
                        _SliderRow(
                          label: 'Оплатить бонусами можно',
                          value: s.loyaltyMaxSpendPercent,
                          min: 10,
                          max: 100,
                          step: 10,
                          suffix: '% заказа',
                          onDone: (v) => save(s.copyWith(loyaltyMaxSpendPercent: v), 'Сохранено'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (api.isDemo) ...[
                const SizedBox(height: 28),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Сбросить демо-данные'),
                    subtitle: const Text(
                      'Вернуть товары, заказы, отзывы и тариф к исходным. Данные демо хранятся в этом браузере.',
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () async {
                        if (!await confirm(context, 'Сбросить все изменения демо?', action: 'Сбросить')) return;
                        await api.resetDemo();
                        await save(await api.getSettings(), 'Демо сброшено');
                      },
                      child: const Text('Сбросить'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _plural(int n) => n % 10 == 1 && n % 100 != 11
      ? 'функция'
      : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? 'функции' : 'функций');
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final info = planInfo[plan]!;
    final color = PlanChip.colorOf(plan);
    final count = Feature.values.where((f) => featureInfo[f]!.plan.index <= plan.index).length;
    final limits = [
      info.productLimit == null ? 'товары без ограничений' : 'до ${info.productLimit} товаров',
      if (info.bannerLimit != null) 'баннеров: ${info.bannerLimit}',
    ].join(' · ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.08) : t.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? color : t.colorScheme.outlineVariant, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: selected ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(info.icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(info.title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: selected
                        ? Icon(Icons.check_circle, key: const ValueKey(true), color: color)
                        : const SizedBox(key: ValueKey(false), width: 24),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(info.tagline, style: t.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                '$count из ${Feature.values.length} функций',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(limits, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final Feature feature;
  final AppSettings settings;
  final ValueChanged<bool> onChanged;
  const _FeatureTile({required this.feature, required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final info = featureInfo[feature]!;
    final blocked = brandBlocks(feature);
    final dep = featureRequires[feature];
    final depOff = dep != null && !isEnabledIn(settings, dep);
    final value = settings.isOn(feature);
    final manual = settings.overrides.containsKey(feature) && settings.overrides[feature] != settings.includedInPlan(feature);
    final active = blocked == null && value && !depOff;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? t.colorScheme.primaryContainer : t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(info.icon, size: 20, color: active ? t.colorScheme.onPrimaryContainer : t.colorScheme.outline),
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(info.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          PlanChip(info.plan, dense: true),
          if (manual)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: t.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(6)),
              child: Text(
                'вручную',
                style: TextStyle(fontSize: 11, color: t.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          blocked ??
              (depOff && value ? '${info.description}. Работает только вместе с «${featureInfo[dep]!.title}»' : info.description),
          style: TextStyle(color: blocked != null || (depOff && value) ? t.colorScheme.error : null),
        ),
      ),
      trailing: Switch(value: value && blocked == null, onChanged: blocked != null ? null : onChanged),
    );
  }
}

class _SliderRow extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onDone;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.suffix,
    required this.onDone,
  });

  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  late double _v = widget.value.toDouble();

  @override
  void didUpdateWidget(_SliderRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _v = widget.value.toDouble();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('${_v.round()}${widget.suffix}'),
        ],
      ),
      Slider(
        value: _v,
        min: widget.min.toDouble(),
        max: widget.max.toDouble(),
        divisions: (widget.max - widget.min) ~/ widget.step,
        onChanged: (v) => setState(() => _v = v),
        onChangeEnd: (v) => widget.onDone(v.round()),
      ),
    ],
  );
}
