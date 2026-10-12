import 'package:flutter/material.dart';

import '../core/models.dart';
import '../ui/widgets/common.dart';
import 'admin_api.dart';
import 'admin_widgets.dart';

/// Категории и баннеры — простые списки с формой редактирования.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  Future<List<DbRow>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AdminScope.of(context).list('categories');
  }

  Future<void> _reload() async {
    final f = AdminScope.of(context).list('categories');
    setState(() {
      _future = f;
    });
    await f.catchError((_) => <DbRow>[]);
  }

  Future<void> _open([DbRow? row]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CategoryForm(row: row)));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Категории'),
      actions: [
        IconButton(tooltip: 'Обновить', icon: const Icon(Icons.refresh), onPressed: _reload),
        const SizedBox(width: 8),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: null,
      onPressed: () => _open(),
      icon: const Icon(Icons.add),
      label: const Text('Категория'),
    ),
    body: AsyncRows(
      future: _future,
      onRefresh: _reload,
      emptyText: 'Категорий пока нет',
      builder: (rows) => ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final r in rows)
            ListTile(
              leading: AdminThumb(
                src: r['image'] as String?,
                color: parseHex(r['color'] as String?),
                icon: categoryIcon(r['icon'] as String?),
              ),
              title: Text(r['title'] as String),
              subtitle: Text('id: ${r['id']} · порядок ${r['sort']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(r),
            ),
        ],
      ),
    ),
  );
}

class CategoryForm extends StatefulWidget {
  final DbRow? row;
  const CategoryForm({super.key, this.row});

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final _form = GlobalKey<FormState>();
  late final DbRow r = widget.row ?? {};
  late final _id = TextEditingController(text: r['id'] as String? ?? '');
  late final _title = TextEditingController(text: r['title'] as String? ?? '');
  late final _sort = TextEditingController(text: '${r['sort'] ?? 0}');
  late String? _icon = r['icon'] as String?;
  late String? _color = r['color'] as String?;
  late String? _image = r['image'] as String?;
  bool _saving = false;

  bool get _isNew => widget.row == null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final api = AdminScope.of(context);
    final data = {
      'title': _title.text.trim(),
      'icon': _icon,
      'color': _color,
      'image': _image,
      'sort': int.tryParse(_sort.text) ?? 0,
    };
    setState(() => _saving = true);
    try {
      _isNew
          ? await api.insert('categories', {'id': _id.text.trim(), ...data})
          : await api.update('categories', r['id'] as Object, data);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Удалить категорию «${_title.text}»?\nТовары останутся, но без категории.')) return;
    if (!mounted) return;
    try {
      await AdminScope.of(context).delete('categories', r['id'] as Object);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isNew ? 'Новая категория' : 'Категория'),
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
          const SizedBox(height: 12),
          TextFormField(
            controller: _id,
            enabled: _isNew,
            decoration: const InputDecoration(
              labelText: 'Код (латиницей) *',
              helperText: 'Например: shoes. После создания не меняется',
            ),
            validator: (v) => RegExp(r'^[a-z0-9_-]+$').hasMatch(v?.trim() ?? '') ? null : 'Только a-z, 0-9, _ и -',
          ),
          const FieldLabel('Иконка'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in categoryIcons.entries)
                IconButton.outlined(
                  tooltip: e.key,
                  isSelected: _icon == e.key,
                  selectedIcon: Icon(e.value),
                  icon: Icon(e.value),
                  onPressed: () => setState(() => _icon = e.key),
                ),
            ],
          ),
          const FieldLabel('Цвет'),
          ColorField(value: _color, onChanged: (v) => setState(() => _color = v)),
          const FieldLabel('Картинка (необязательно)'),
          ImagesField(single: true, images: [?_image], onChanged: (v) => setState(() => _image = v.firstOrNull)),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _sort,
              decoration: const InputDecoration(labelText: 'Порядок'),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    ),
  );
}

class BannersPage extends StatefulWidget {
  const BannersPage({super.key});

  @override
  State<BannersPage> createState() => _BannersPageState();
}

class _BannersPageState extends State<BannersPage> {
  Future<List<DbRow>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AdminScope.of(context).list('banners');
  }

  Future<void> _reload() async {
    final f = AdminScope.of(context).list('banners');
    setState(() {
      _future = f;
    });
    await f.catchError((_) => <DbRow>[]);
  }

  Future<void> _open([DbRow? row]) async {
    final api = AdminScope.of(context);
    if (row == null) {
      final count = (await _future)?.length ?? 0;
      if (!mounted) return;
      final limit = AdminSettings.of(context).settings.info.bannerLimit;
      if (!await checkLimit(context, count: count, limit: limit, what: 'баннеров')) return;
    }
    final (cats, prods) = await (api.list('categories'), api.list('products')).wait;
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BannerForm(row: row, categories: cats, products: prods),
      ),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: FutureBuilder<List<DbRow>>(
        future: _future,
        builder: (context, snap) =>
            UsageTitle('Баннеры и сторис', count: snap.data?.length, limit: AdminSettings.of(context).settings.info.bannerLimit),
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
      label: const Text('Баннер'),
    ),
    body: AsyncRows(
      future: _future,
      onRefresh: _reload,
      emptyText: 'Баннеров пока нет',
      builder: (rows) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: r['active'] == true ? 1 : 0.45,
                child: Material(
                  color: parseHex(r['color'] as String?) ?? Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(r),
                    child: Stack(
                      children: [
                        if (r['image'] != null) Positioned.fill(child: AppImage(src: r['image'] as String)),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['title'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                                if (r['subtitle'] != null)
                                  Text(r['subtitle'] as String, style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class BannerForm extends StatefulWidget {
  final DbRow? row;
  final List<DbRow> categories;
  final List<DbRow> products;
  const BannerForm({super.key, this.row, required this.categories, required this.products});

  @override
  State<BannerForm> createState() => _BannerFormState();
}

class _BannerFormState extends State<BannerForm> {
  final _form = GlobalKey<FormState>();
  late final DbRow r = widget.row ?? {};
  late final _title = TextEditingController(text: r['title'] as String? ?? '');
  late final _subtitle = TextEditingController(text: r['subtitle'] as String? ?? '');
  late final _sort = TextEditingController(text: '${r['sort'] ?? 0}');
  late String? _color = r['color'] as String? ?? brandSwatches.first;
  late String? _image = r['image'] as String?;
  late String? _category = r['category_id'] as String?;
  late String? _product = r['product_id'] as String?;
  late bool _active = r['active'] as bool? ?? true;
  bool _saving = false;

  bool get _isNew => widget.row == null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final api = AdminScope.of(context);
    final data = {
      'title': _title.text.trim(),
      'subtitle': _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
      'color': _color,
      'image': _image,
      'category_id': _category,
      'product_id': _product,
      'active': _active,
      'sort': int.tryParse(_sort.text) ?? 0,
    };
    setState(() => _saving = true);
    try {
      _isNew ? await api.insert('banners', data) : await api.update('banners', r['id'] as Object, data);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Удалить баннер?')) return;
    if (!mounted) return;
    try {
      await AdminScope.of(context).delete('banners', r['id'] as Object);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isNew ? 'Новый баннер' : 'Баннер'),
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
            decoration: const InputDecoration(labelText: 'Заголовок *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subtitle,
            decoration: const InputDecoration(labelText: 'Подзаголовок'),
          ),
          const FieldLabel('Цвет фона'),
          ColorField(value: _color, onChanged: (v) => setState(() => _color = v)),
          const FieldLabel('Картинка (необязательно)'),
          ImagesField(single: true, images: [?_image], onChanged: (v) => setState(() => _image = v.firstOrNull)),
          const FieldLabel('По нажатию открывать'),
          DropdownButtonFormField<String?>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Категорию'),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              for (final c in widget.categories) DropdownMenuItem(value: c['id'] as String, child: Text(c['title'] as String)),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _product,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'или товар (важнее категории)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              for (final p in widget.products)
                DropdownMenuItem(
                  value: p['id'] as String,
                  child: Text(p['title'] as String, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _product = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Показывать'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _sort,
              decoration: const InputDecoration(labelText: 'Порядок'),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    ),
  );
}
