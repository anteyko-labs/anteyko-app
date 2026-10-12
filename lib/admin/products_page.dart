import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../ui/widgets/common.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  Future<List<DbRow>>? _future;
  List<DbRow> _categories = [];
  String _query = '';
  String? _category;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null) _reload();
  }

  Future<void> _reload() async {
    final api = AdminScope.of(context);
    final f = api.list('products');
    setState(() {
      _future = f;
    });
    try {
      final cats = await api.list('categories');
      if (mounted) setState(() => _categories = cats);
      await f;
    } catch (_) {}
  }

  DbRow? _cat(String? id) => _categories.where((c) => c['id'] == id).firstOrNull;

  Future<void> _open([DbRow? row]) async {
    if (row == null) {
      final count = (await _future)?.length ?? 0;
      if (!mounted) return;
      final limit = AdminSettings.of(context).settings.info.productLimit;
      if (!await checkLimit(context, count: count, limit: limit, what: 'товаров')) return;
      if (!mounted) return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductForm(row: row, categories: _categories),
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _quick(DbRow row, String field, bool value) async {
    try {
      await AdminScope.of(context).update('products', row['id'] as Object, {field: value});
      setState(() => row[field] = value);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<List<DbRow>>(
          future: _future,
          builder: (context, snap) =>
              UsageTitle('Товары', count: snap.data?.length, limit: AdminSettings.of(context).settings.info.productLimit),
        ),
        actions: [
          IconButton(tooltip: 'Обновить', icon: const Icon(Icons.refresh), onPressed: _reload),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Товар'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск по названию'),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Все'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final c in _categories)
                  ChoiceChip(
                    label: Text(c['title'] as String),
                    selected: _category == c['id'],
                    onSelected: (_) => setState(() => _category = c['id'] as String),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncRows(
              future: _future,
              onRefresh: _reload,
              emptyText: 'Товаров пока нет',
              builder: (all) {
                final rows = all
                    .where((r) => _category == null || r['category_id'] == _category)
                    .where((r) => _query.isEmpty || (r['title'] as String).toLowerCase().contains(_query))
                    .toList();
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 84, endIndent: 16),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final cat = _cat(r['category_id'] as String?);
                    final images = (r['images'] as List?)?.cast<String>() ?? const [];
                    final active = r['active'] == true;
                    return Opacity(
                      opacity: active ? 1 : 0.5,
                      child: ListTile(
                        leading: AdminThumb(
                          src: images.firstOrNull,
                          color: parseHex(cat?['color'] as String?),
                          icon: categoryIcon(cat?['icon'] as String?),
                        ),
                        title: Text(r['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            r['price'] == null ? 'цена по запросу' : formatMoney(r['price'] as num),
                            if (cat != null) cat['title'],
                            if (!active) 'скрыт',
                            if (r['featured'] == true) '★',
                          ].join(' · '),
                        ),
                        trailing: Tooltip(
                          message: 'В наличии',
                          child: Switch(value: r['in_stock'] == true, onChanged: (v) => _quick(r, 'in_stock', v)),
                        ),
                        onTap: () => _open(r),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductForm extends StatefulWidget {
  final DbRow? row;
  final List<DbRow> categories;
  const ProductForm({super.key, this.row, required this.categories});

  @override
  State<ProductForm> createState() => _ProductFormState();
}

typedef _Pair = MapEntry<TextEditingController, TextEditingController>;

class _ProductFormState extends State<ProductForm> {
  final _form = GlobalKey<FormState>();
  late final DbRow r = widget.row ?? {};
  late final _title = TextEditingController(text: r['title'] as String? ?? '');
  late final _price = TextEditingController(text: numText(r['price']));
  late final _oldPrice = TextEditingController(text: numText(r['old_price']));
  late final _unit = TextEditingController(text: r['unit'] as String? ?? '');
  late final _desc = TextEditingController(text: r['description'] as String? ?? '');
  late final _badges = TextEditingController(text: ((r['badges'] as List?) ?? []).join(', '));
  late final _sort = TextEditingController(text: '${r['sort'] ?? 0}');
  late String? _category = r['category_id'] as String? ?? widget.categories.firstOrNull?['id'] as String?;
  late List<String> _images = ((r['images'] as List?) ?? []).cast<String>().toList();
  late bool _inStock = r['in_stock'] as bool? ?? true;
  late bool _featured = r['featured'] as bool? ?? false;
  late bool _active = r['active'] as bool? ?? true;
  late final List<_Pair> _options = [
    for (final o in (r['options'] as List?) ?? [])
      MapEntry(TextEditingController(text: o['name'] as String), TextEditingController(text: (o['values'] as List).join(', '))),
  ];
  late final List<_Pair> _specs = [
    for (final e in ((r['specs'] as Map?) ?? {}).entries)
      MapEntry(TextEditingController(text: e.key as String), TextEditingController(text: '${e.value}')),
  ];
  bool _saving = false;

  bool get _isNew => widget.row == null;

  List<String> _split(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final api = AdminScope.of(context);
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'category_id': _category,
      'price': parseNum(_price.text),
      'old_price': parseNum(_oldPrice.text),
      'unit': _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      'description': _desc.text.trim(),
      'badges': _split(_badges.text),
      'images': _images,
      'options': [
        for (final o in _options)
          if (o.key.text.trim().isNotEmpty && _split(o.value.text).isNotEmpty)
            {'name': o.key.text.trim(), 'values': _split(o.value.text)},
      ],
      'specs': {
        for (final s in _specs)
          if (s.key.text.trim().isNotEmpty) s.key.text.trim(): s.value.text.trim(),
      },
      'in_stock': _inStock,
      'featured': _featured,
      'active': _active,
      'sort': int.tryParse(_sort.text.trim()) ?? 0,
    };
    setState(() => _saving = true);
    try {
      _isNew ? await api.insert('products', data) : await api.update('products', r['id'] as Object, data);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Удалить «${_title.text}»?')) return;
    if (!mounted) return;
    try {
      await AdminScope.of(context).delete('products', r['id'] as Object);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String? _money(String? v) => (v == null || v.trim().isEmpty || parseNum(v) != null) ? null : 'Введите число';

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Новый товар' : 'Товар'),
        actions: [
          if (!_isNew) IconButton(tooltip: 'Удалить', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: _saving ? null : _save,
              child: const Text('Сохранить'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Название *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
            ),
            gap,
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Категория'),
              items: [
                for (final c in widget.categories) DropdownMenuItem(value: c['id'] as String, child: Text(c['title'] as String)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            gap,
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Цена', helperText: 'Пусто — по запросу'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _money,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _oldPrice,
                    decoration: const InputDecoration(labelText: 'Старая цена', helperText: 'Для скидки'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _money,
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Ед.', helperText: 'кг, шт…'),
                  ),
                ),
              ],
            ),
            const FieldLabel('Фото'),
            ImagesField(images: _images, onChanged: (v) => setState(() => _images = v)),
            const FieldLabel('Описание'),
            TextField(controller: _desc, minLines: 3, maxLines: 10),
            gap,
            TextField(
              controller: _badges,
              decoration: const InputDecoration(labelText: 'Бейджи', helperText: 'Через запятую: Хит, Новинка'),
            ),
            const FieldLabel('Варианты (размер, цвет, объём…)'),
            KeyValueEditor(
              rows: _options,
              keyHint: 'Размер',
              valueHint: 'S, M, L — через запятую',
              onChanged: () => setState(() {}),
            ),
            const FieldLabel('Характеристики'),
            KeyValueEditor(rows: _specs, keyHint: 'Состав', valueHint: '100% хлопок', onChanged: () => setState(() {})),
            const FieldLabel('Показ'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('В наличии'),
              value: _inStock,
              onChanged: (v) => setState(() => _inStock = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Популярное'),
              subtitle: const Text('Показывать в блоке на главной'),
              value: _featured,
              onChanged: (v) => setState(() => _featured = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Опубликован'),
              subtitle: const Text('Выключите, чтобы скрыть из приложения'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            gap,
            SizedBox(
              width: 200,
              child: TextField(
                controller: _sort,
                decoration: const InputDecoration(labelText: 'Порядок', helperText: 'Меньше — выше в списке'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
