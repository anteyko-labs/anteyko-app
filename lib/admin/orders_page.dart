import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/order_service.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

const orderStatuses = {
  'new': 'Новый',
  'confirmed': 'Подтверждён',
  'delivering': 'В доставке',
  'done': 'Выполнен',
  'cancelled': 'Отменён',
};

Color statusColor(BuildContext context, String s) {
  final scheme = Theme.of(context).colorScheme;
  return switch (s) {
    'new' => scheme.primary,
    'confirmed' => const Color(0xFF0E7490),
    'delivering' => const Color(0xFFB45309),
    'done' => const Color(0xFF15803D),
    _ => scheme.outline,
  };
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        orderStatuses[status] ?? status,
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String? _status;
  Future<List<DbRow>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AdminScope.of(context).orders(status: _status);
  }

  Future<void> _reload() async {
    final f = AdminScope.of(context).orders(status: _status);
    setState(() {
      _future = f;
    });
    await f.catchError((_) => <DbRow>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказы'),
        actions: [
          IconButton(tooltip: 'Обновить', icon: const Icon(Icons.refresh), onPressed: _reload),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Все'),
                  selected: _status == null,
                  onSelected: (_) {
                    _status = null;
                    _reload();
                  },
                ),
                for (final e in orderStatuses.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: (_) {
                      _status = e.key;
                      _reload();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncRows(
              future: _future,
              onRefresh: _reload,
              emptyText: 'Заказов нет',
              builder: (rows) => ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final o = rows[i];
                  final created = DateTime.parse(o['created_at'] as String).toLocal();
                  return ListTile(
                    title: Text('№${o['id']} · ${o['customer_name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${formatDate(created)} · ${o['customer_phone']} · ${o['is_delivery'] == true ? 'доставка' : 'самовывоз'}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 4,
                      children: [
                        Text(formatMoney(o['total'] as num), style: const TextStyle(fontWeight: FontWeight.w700)),
                        StatusChip(o['status'] as String),
                      ],
                    ),
                    onTap: () async {
                      final changed = await Navigator.of(context)
                          .push<bool>(MaterialPageRoute(builder: (_) => OrderDetailPage(order: o)));
                      if (changed == true) _reload();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  final DbRow order;
  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late String _status = widget.order['status'] as String;
  late final _note = TextEditingController(text: widget.order['admin_note'] as String? ?? '');
  bool _saving = false;
  bool _changed = false;

  DbRow get o => widget.order;

  Future<void> _save({String? status}) async {
    setState(() => _saving = true);
    try {
      await AdminScope.of(context).updateOrder(o['id'] as Object, {'status': status ?? _status, 'admin_note': _note.text.trim()});
      _changed = true;
      if (status != null) _status = status;
      if (mounted) showDone(context, 'Сохранено');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final lines = (o['lines'] as List).cast<Map<String, dynamic>>();
    final phone = o['customer_phone'] as String;
    final created = DateTime.parse(o['created_at'] as String).toLocal();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Заказ №${o['id']}')),
        body: FormBody(
          children: [
            Text(formatDate(created), style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
            const FieldLabel('Статус'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in orderStatuses.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: _saving ? null : (_) => _save(status: e.key),
                  ),
              ],
            ),
            const FieldLabel('Покупатель'),
            Card(
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.person_outline), title: Text(o['customer_name'] as String)),
                  ListTile(
                    leading: const Icon(Icons.call_outlined),
                    title: Text(phone),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Позвонить',
                          icon: const Icon(Icons.call),
                          onPressed: () => openLink('tel:${phone.replaceAll(' ', '')}'),
                        ),
                        IconButton(
                          tooltip: 'WhatsApp',
                          icon: const Icon(Icons.chat_outlined),
                          onPressed: () => openLink('https://wa.me/${phone.replaceAll(RegExp(r'\D'), '')}'),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(o['is_delivery'] == true ? Icons.local_shipping_outlined : Icons.storefront_outlined),
                    title: Text(o['is_delivery'] == true ? (o['address'] as String? ?? '') : 'Самовывоз'),
                    subtitle: Text('Оплата: ${paymentLabel(o['payment'] as String).toLowerCase()}'),
                  ),
                  if ((o['comment'] as String? ?? '').isNotEmpty)
                    ListTile(leading: const Icon(Icons.comment_outlined), title: Text(o['comment'] as String)),
                ],
              ),
            ),
            const FieldLabel('Состав'),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l['title']} × ${l['quantity']}'),
                          if ((l['options'] as Map?)?.isNotEmpty ?? false)
                            Text(
                              optionsLabel(Map<String, String>.from(l['options'] as Map)),
                              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    Text(formatMoney((l['price'] as num) * (l['quantity'] as num))),
                  ],
                ),
              ),
            const Divider(height: 24),
            _sum('Товары', o['subtotal'] as num),
            _sum('Доставка', o['delivery_fee'] as num),
            _sum('Итого', o['total'] as num, bold: true),
            const FieldLabel('Заметка для себя'),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'Видна только в админке'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(onPressed: _saving ? null : () => _save(), child: const Text('Сохранить заметку')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sum(String label, num v, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 17 : 15);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(formatMoney(v), style: style),
        ],
      ),
    );
  }
}
