import 'package:flutter/material.dart';

import '../core/features.dart';
import '../core/format.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

/// Промокоды хранятся в настройках приложения (app_settings).
class PromoCodesPage extends StatelessWidget {
  const PromoCodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AdminSettings.of(context);
    final codes = scope.settings.promoCodes;
    final t = Theme.of(context);

    Future<void> setCodes(List<PromoCode> list, String done) async {
      try {
        await scope.save(scope.settings.copyWith(promoCodes: list));
        if (context.mounted) showDone(context, done);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    Future<void> edit([PromoCode? code]) async {
      final result = await showModalBottomSheet<PromoCode>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _PromoForm(code: code),
      );
      if (result == null) return;
      final list = [...codes.where((c) => c.code != (code?.code ?? result.code)), result];
      await setCodes(list, code == null ? 'Промокод создан' : 'Сохранено');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Промокоды')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: edit,
        icon: const Icon(Icons.add),
        label: const Text('Промокод'),
      ),
      body: codes.isEmpty
          ? const Center(child: Text('Промокодов пока нет'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                for (final c in codes)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.active ? t.colorScheme.primaryContainer : t.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          c.percent > 0 ? '${c.percent}%' : formatMoney(c.amount),
                          style: TextStyle(fontWeight: FontWeight.w800, color: t.colorScheme.onPrimaryContainer),
                        ),
                      ),
                      title: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                      subtitle: Text(c.minSum > 0 ? 'Заказ от ${formatMoney(c.minSum)}' : 'Без минимальной суммы'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: c.active,
                            onChanged: (v) => setCodes([
                              for (final x in codes)
                                x.code == c.code
                                    ? PromoCode(code: x.code, percent: x.percent, amount: x.amount, minSum: x.minSum, active: v)
                                    : x,
                            ], v ? 'Промокод включён' : 'Промокод выключен'),
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await confirm(context, 'Удалить промокод ${c.code}?')) return;
                              await setCodes([...codes.where((x) => x.code != c.code)], 'Удалено');
                            },
                          ),
                        ],
                      ),
                      onTap: () => edit(c),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PromoForm extends StatefulWidget {
  final PromoCode? code;
  const _PromoForm({this.code});

  @override
  State<_PromoForm> createState() => _PromoFormState();
}

class _PromoFormState extends State<_PromoForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.code?.code ?? '');
  late bool _percent = (widget.code?.percent ?? 10) > 0;
  late final _value = TextEditingController(
    text: widget.code == null ? '10' : numText(widget.code!.percent > 0 ? widget.code!.percent : widget.code!.amount),
  );
  late final _min = TextEditingController(text: numText(widget.code?.minSum ?? 0));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.code == null ? 'Новый промокод' : 'Промокод', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              enabled: widget.code == null,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Код', hintText: 'SUMMER20'),
              validator: (v) =>
                  RegExp(r'^[A-Za-z0-9_-]{3,20}$').hasMatch(v?.trim() ?? '') ? null : '3–20 символов: латиница и цифры',
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Процент')),
                ButtonSegment(value: false, label: Text('Сумма')),
              ],
              selected: {_percent},
              onSelectionChanged: (s) => setState(() => _percent = s.first),
            ),
            const SizedBox(height: 14),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _percent ? 'Скидка, %' : 'Скидка, сумма'),
                    validator: (v) {
                      final n = parseNum(v ?? '');
                      if (n == null || n <= 0) return 'Введите число';
                      if (_percent && n > 90) return 'Не больше 90%';
                      return null;
                    },
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Заказ от'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                final v = parseNum(_value.text)!;
                Navigator.pop(
                  context,
                  PromoCode(
                    code: _code.text.trim().toUpperCase(),
                    percent: _percent ? v.round() : 0,
                    amount: _percent ? 0 : v,
                    minSum: parseNum(_min.text) ?? 0,
                    active: widget.code?.active ?? true,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Модерация отзывов: новые ждут одобрения, одобренные видны в приложении.
class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  Future<(List<DbRow>, List<DbRow>)>? _future;
  bool _pendingOnly = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<(List<DbRow>, List<DbRow>)> _load() {
    final api = AdminScope.of(context);
    return (api.reviews(), api.list('products')).wait;
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
    final api = AdminScope.of(context);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отзывы'),
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
          final (reviews, products) = snap.data!;
          final titles = {for (final p in products) '${p['id']}': p['title'] as String};
          final pending = reviews.where((r) => r['approved'] != true).length;
          final list = reviews.where((r) => !_pendingOnly || r['approved'] != true).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('На модерации · $pending'),
                      selected: _pendingOnly,
                      onSelected: (_) => setState(() => _pendingOnly = true),
                    ),
                    ChoiceChip(
                      label: Text('Все · ${reviews.length}'),
                      selected: !_pendingOnly,
                      onSelected: (_) => setState(() => _pendingOnly = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Новых отзывов нет'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final r = list[i];
                          final approved = r['approved'] == true;
                          final rating = (r['rating'] as num).toInt();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      for (var k = 0; k < 5; k++)
                                        Icon(
                                          k < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                          size: 18,
                                          color: const Color(0xFFF5A524),
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${r['name']} · ${titles['${r['product_id']}'] ?? 'товар удалён'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!approved)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: t.colorScheme.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('новый', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(r['text'] as String),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Удалить'),
                                        onPressed: () async {
                                          await api.deleteReview(r['id'] as Object);
                                          await _reload();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      approved
                                          ? OutlinedButton(
                                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                                              onPressed: () async {
                                                await api.setReviewApproved(r['id'] as Object, false);
                                                await _reload();
                                              },
                                              child: const Text('Скрыть'),
                                            )
                                          : FilledButton.icon(
                                              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                                              icon: const Icon(Icons.check),
                                              label: const Text('Опубликовать'),
                                              onPressed: () async {
                                                await api.setReviewApproved(r['id'] as Object, true);
                                                await _reload();
                                                if (context.mounted) showDone(context, 'Отзыв опубликован');
                                              },
                                            ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
