import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/features.dart';
import '../core/models.dart';
import '../ui/widgets/common.dart';
import 'admin_api.dart';

/// Доступ к AdminApi из любого места админки.
class AdminScope extends InheritedWidget {
  final AdminApi api;
  const AdminScope({super.key, required this.api, required super.child});

  static AdminApi of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AdminScope>()!.api;

  @override
  bool updateShouldNotify(AdminScope old) => api != old.api;
}

void showError(BuildContext context, Object e) {
  final text = e.toString().replaceFirst('Exception: ', '');
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: Theme.of(context).colorScheme.error));
}

void showDone(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<bool> confirm(BuildContext context, String title, {String action = 'Удалить'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

num? parseNum(String s) => num.tryParse(s.replaceAll(' ', '').replaceAll(',', '.'));

String numText(Object? v) {
  if (v == null) return '';
  final n = v is num ? v : num.tryParse(v.toString());
  if (n == null) return '';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

/// Ограничивает ширину формы на больших экранах.
class FormBody extends StatelessWidget {
  final List<Widget> children;
  const FormBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: children),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
  );
}

/// Миниатюра: картинка по URL или заглушка.
class AdminThumb extends StatelessWidget {
  final String? src;
  final Color? color;
  final IconData icon;
  final double size;
  const AdminThumb({super.key, this.src, this.color, this.icon = Icons.image_outlined, this.size = 52});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: size,
      height: size,
      child: AppImage(src: src, color: color, icon: icon, iconSize: size * 0.45),
    ),
  );
}

/// Список картинок: загрузка файла, вставка URL, удаление, «сделать главной».
class ImagesField extends StatefulWidget {
  final List<String> images;
  final ValueChanged<List<String>> onChanged;
  final bool single;
  const ImagesField({super.key, required this.images, required this.onChanged, this.single = false});

  @override
  State<ImagesField> createState() => _ImagesFieldState();
}

class _ImagesFieldState extends State<ImagesField> {
  bool _uploading = false;

  void _set(List<String> list) => widget.onChanged(widget.single ? list.take(1).toList() : list);

  Future<void> _upload() async {
    final api = AdminScope.of(context);
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      setState(() => _uploading = true);
      final url = await api.uploadImage(await file.readAsBytes(), file.name);
      _set(widget.single ? [url] : [...widget.images, url]);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _addUrl() async {
    final c = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ссылка на картинку'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Добавить')),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) _set(widget.single ? [url] : [...widget.images, url]);
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < imgs.length; i++)
          Stack(
            children: [
              AdminThumb(src: imgs[i], size: 96),
              if (i == 0 && imgs.length > 1) const Positioned(left: 4, bottom: 4, child: Tag('Главная')),
              Positioned(
                right: 0,
                top: 0,
                child: PopupMenuButton<String>(
                  icon: const CircleAvatar(radius: 13, child: Icon(Icons.more_horiz, size: 16)),
                  onSelected: (v) {
                    final list = [...imgs];
                    final item = list.removeAt(i);
                    if (v == 'main') list.insert(0, item);
                    _set(list);
                  },
                  itemBuilder: (_) => [
                    if (i > 0) const PopupMenuItem(value: 'main', child: Text('Сделать главной')),
                    const PopupMenuItem(value: 'del', child: Text('Убрать')),
                  ],
                ),
              ),
            ],
          ),
        if (!widget.single || imgs.isEmpty) ...[
          SizedBox(
            width: 96,
            height: 96,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload),
                        SizedBox(height: 4),
                        Text('Загрузить', style: TextStyle(fontSize: 12)),
                      ],
                    ),
            ),
          ),
          TextButton.icon(onPressed: _addUrl, icon: const Icon(Icons.link, size: 18), label: const Text('По ссылке')),
        ],
      ],
    );
  }
}

/// Пары «ключ — значение» (характеристики).
class KeyValueEditor extends StatelessWidget {
  final List<MapEntry<TextEditingController, TextEditingController>> rows;
  final VoidCallback onChanged;
  final String keyHint;
  final String valueHint;
  const KeyValueEditor({
    super.key,
    required this.rows,
    required this.onChanged,
    this.keyHint = 'Название',
    this.valueHint = 'Значение',
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: r.key,
                  decoration: InputDecoration(hintText: keyHint),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: r.value,
                  decoration: InputDecoration(hintText: valueHint),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  rows.remove(r);
                  onChanged();
                },
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Добавить строку'),
          onPressed: () {
            rows.add(MapEntry(TextEditingController(), TextEditingController()));
            onChanged();
          },
        ),
      ),
    ],
  );
}

const brandSwatches = [
  '#2F5BEA',
  '#5B6CFF',
  '#0F766E',
  '#2BB0A6',
  '#3DA35D',
  '#C9A227',
  '#F5C451',
  '#FF7A45',
  '#E5484D',
  '#E85D9A',
  '#B57EDC',
  '#1F2937',
];

class ColorField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const ColorField({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hex in brandSwatches)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onChanged(hex),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: parseHex(hex),
                shape: BoxShape.circle,
                border: Border.all(color: value?.toUpperCase() == hex ? scheme.onSurface : Colors.transparent, width: 3),
              ),
            ),
          ),
        ActionChip(label: const Text('Без цвета'), onPressed: () => onChanged(null)),
      ],
    );
  }
}

/// Загрузка списка с обработкой ошибок и «потяни, чтобы обновить».
class AsyncRows extends StatelessWidget {
  final Future<List<DbRow>>? future;
  final Future<void> Function() onRefresh;
  final Widget Function(List<DbRow> rows) builder;
  final String emptyText;
  const AsyncRows({super.key, required this.future, required this.onRefresh, required this.builder, this.emptyText = 'Пусто'});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DbRow>>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snap.hasError) {
        return EmptyState(
          icon: Icons.cloud_off,
          title: 'Ошибка загрузки',
          hint: '${snap.error}',
          action: FilledButton.tonal(onPressed: onRefresh, child: const Text('Повторить')),
        );
      }
      final rows = snap.data!;
      if (rows.isEmpty) return EmptyState(icon: Icons.inbox_outlined, title: emptyText);
      return RefreshIndicator(onRefresh: onRefresh, child: builder(rows));
    },
  );
}

/// Текущие настройки (тариф, функции) внутри админки + сохранение.
class AdminSettings extends InheritedWidget {
  final AppSettings settings;
  final Future<void> Function(AppSettings) save;
  const AdminSettings({super.key, required this.settings, required this.save, required super.child});

  static AdminSettings of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AdminSettings>()!;

  /// Функция действительно работает в приложении (тариф + бренд + зависимости).
  bool on(Feature f) => isEnabledIn(settings, f);

  @override
  bool updateShouldNotify(AdminSettings old) => old.settings != settings;
}

/// Плашка «доступно в тарифе …» с кнопкой включения.
class UpsellCard extends StatelessWidget {
  final Feature feature;
  final VoidCallback? onEnable;
  const UpsellCard({super.key, required this.feature, this.onEnable});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final info = featureInfo[feature]!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: t.colorScheme.primaryContainer.withValues(alpha: 0.55),
        border: Border.all(color: t.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(info.icon, size: 34, color: t.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${info.description}. Входит в тариф «${planInfo[info.plan]!.title}».', style: t.textTheme.bodyMedium),
              ],
            ),
          ),
          if (onEnable != null) ...[
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: onEnable,
              child: const Text('Включить'),
            ),
          ],
        ],
      ),
    );
  }
}

class PlanChip extends StatelessWidget {
  final Plan plan;
  final bool dense;
  const PlanChip(this.plan, {super.key, this.dense = false});

  static Color colorOf(Plan p) => switch (p) {
    Plan.start => const Color(0xFF64748B),
    Plan.business => const Color(0xFF2F5BEA),
    Plan.premium => const Color(0xFFB45309),
  };

  @override
  Widget build(BuildContext context) {
    final c = colorOf(plan);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        planInfo[plan]!.title,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: dense ? 11 : 12),
      ),
    );
  }
}

/// Проверка лимита тарифа перед добавлением. true — можно добавлять.
Future<bool> checkLimit(BuildContext context, {required int count, required int? limit, required String what}) async {
  if (limit == null || count < limit) return true;
  final plan = AdminSettings.of(context).settings.plan;
  final next = Plan.values.where((p) => p.index > plan.index).firstOrNull;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text('Лимит тарифа: $limit $what'),
      content: Text(
        next == null
            ? 'Удалите ненужное, чтобы добавить новое.'
            : 'В тарифе «${planInfo[next]!.title}» лимит выше. Тариф меняется в разделе «Тариф».',
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))],
    ),
  );
  return false;
}

/// «27 / 30» рядом с заголовком списка.
class UsageTitle extends StatelessWidget {
  final String title;
  final int? count;
  final int? limit;
  const UsageTitle(this.title, {super.key, this.count, this.limit});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (count == null) return Text(title);
    final full = limit != null && count! >= limit!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: full ? t.colorScheme.errorContainer : t.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            limit == null ? '$count' : '$count / $limit',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: full ? t.colorScheme.onErrorContainer : null),
          ),
        ),
      ],
    );
  }
}
