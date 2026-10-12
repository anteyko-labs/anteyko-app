import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../motion.dart';
import '../widgets/confetti.dart';

/// Онлайн-запись на услугу: мастер → дата → время → контакты.
Future<void> openBooking(BuildContext context, Product service) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _BookingSheet(service: service),
);

/// Заявка менеджеру (шоурум, цена по запросу).
Future<void> openRequest(BuildContext context, Product? product) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _RequestSheet(product: product),
);

const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

class _BookingSheet extends StatefulWidget {
  final Product service;
  const _BookingSheet({required this.service});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late final List<String> _masters =
      widget.service.options.where((o) => o.name == 'Мастер').firstOrNull?.values ?? const ['Любой мастер'];
  late String _master = _masters.first;
  final _days = List.generate(14, (i) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(Duration(days: i));
  });
  // Первый день, где есть свободное время (вечером «сегодня» уже занято).
  late DateTime _day = _days.firstWhere((d) => _slots.any((s) => !_busyOn(d, s)), orElse: () => _days.first);
  String? _time;
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: AppState.of(context).customer.name);
  late final _phone = TextEditingController(text: AppState.of(context).customer.phone);
  bool _done = false;

  List<String> get _slots => [
    for (var h = 10; h < 20; h++) ...['$h:00', '$h:30'],
  ];

  /// Часть слотов «занята» — детерминированно от даты, мастера и услуги.
  bool _busy(String slot) => _busyOn(_day, slot);

  bool _busyOn(DateTime day, String slot) {
    final parts = slot.split(':');
    final at = day.add(Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1])));
    if (at.isBefore(DateTime.now().add(const Duration(hours: 1)))) return true;
    return ('${day.day}$_master$slot${widget.service.id}'.hashCode % 5) == 0;
  }

  void _confirm() {
    if (_time == null || !_form.currentState!.validate()) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = widget.service;
    if (_done) {
      return _Success(
        title: 'Вы записаны!',
        lines: [
          s.title,
          '${_day.day} ${_months[_day.month - 1]}, $_time',
          if (_masters.length > 1) 'Мастер: $_master',
          if (brand.contacts.address != null) brand.contacts.address!,
        ],
        hint: 'Напомним за 2 часа до визита',
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(s.title, style: t.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              [formatPrice(s.price), ?s.specs['Длительность']].join(' · '),
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            if (_masters.length > 1) ...[
              const _Label('Мастер'),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _masters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (_, i) {
                    final m = _masters[i];
                    final on = m == _master;
                    return Pressable(
                      onTap: () => setState(() {
                        _master = m;
                        _time = null;
                      }),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: motionMedium,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: on ? t.colorScheme.primary : Colors.transparent, width: 2.5),
                            ),
                            child: CircleAvatar(
                              radius: 27,
                              backgroundColor: on ? t.colorScheme.primary : t.colorScheme.primaryContainer,
                              child: m == 'Любой'
                                  ? Icon(
                                      Icons.groups_outlined,
                                      color: on ? t.colorScheme.onPrimary : t.colorScheme.onPrimaryContainer,
                                    )
                                  : Text(
                                      m.characters.first,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: on ? t.colorScheme.onPrimary : t.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(m, style: t.textTheme.labelMedium),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const _Label('Дата'),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final d = _days[i];
                  final on = d == _day;
                  return Pressable(
                    onTap: () => setState(() {
                      _day = d;
                      _time = null;
                    }),
                    child: AnimatedContainer(
                      duration: motionMedium,
                      curve: motionCurve,
                      width: 56,
                      decoration: BoxDecoration(
                        color: on ? t.colorScheme.primary : t.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(brand.cornerRadius * 0.7),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            i == 0 ? 'Сег.' : _weekdays[d.weekday - 1],
                            style: TextStyle(fontSize: 12, color: on ? t.colorScheme.onPrimary : t.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: on ? t.colorScheme.onPrimary : t.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const _Label('Время'),
            AnimatedSwitcher(
              duration: motionMedium,
              child: Wrap(
                key: ValueKey('$_day$_master'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in _slots)
                    ChoiceChip(
                      label: Text(slot),
                      selected: _time == slot,
                      onSelected: _busy(slot) ? null : (_) => setState(() => _time = slot),
                    ),
                ],
              ),
            ),
            const _Label('Ваши контакты'),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: S.name),
              validator: (v) => (v ?? '').trim().isEmpty ? S.required : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: S.phone),
              keyboardType: TextInputType.phone,
              validator: (v) => (v ?? '').trim().isEmpty ? S.required : null,
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              duration: motionMedium,
              opacity: _time == null ? 0.5 : 1,
              child: FilledButton(
                onPressed: _time == null ? null : _confirm,
                child: Text(_time == null ? 'Выберите время' : 'Записаться на ${_day.day} ${_months[_day.month - 1]}, $_time'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  final Product? product;
  const _RequestSheet({required this.product});

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: AppState.of(context).customer.name);
  late final _phone = TextEditingController(text: AppState.of(context).customer.phone);
  final _comment = TextEditingController();
  late final Map<String, String> _sel = {
    for (final o in widget.product?.options ?? const <ProductOption>[])
      if (o.values.isNotEmpty) o.name: o.values.first,
  };
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = widget.product;
    if (_done) {
      return _Success(
        title: 'Заявка отправлена',
        lines: [p?.title ?? 'Консультация', if (_sel.isNotEmpty) optionsLabel(_sel)],
        hint: 'Менеджер перезвонит в течение 15 минут в рабочее время',
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(p == null ? 'Консультация дизайнера' : (brand.contactLabel ?? S.contactUs), style: t.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              p?.title ?? 'Перезвоним и договоримся о времени',
              style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            for (final o in p?.options ?? const <ProductOption>[]) ...[
              _Label(o.name),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in o.values)
                    ChoiceChip(label: Text(v), selected: _sel[o.name] == v, onSelected: (_) => setState(() => _sel[o.name] = v)),
                ],
              ),
            ],
            const _Label('Как с вами связаться'),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: S.name),
              validator: (v) => (v ?? '').trim().isEmpty ? S.required : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: S.phone),
              keyboardType: TextInputType.phone,
              validator: (v) => (v ?? '').trim().isEmpty ? S.required : null,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Комментарий', hintText: 'Размеры помещения, удобное время звонка…'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) setState(() => _done = true);
              },
              child: const Text('Отправить заявку'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
  );
}

/// Экран успеха с анимированной галочкой.
class _Success extends StatelessWidget {
  final String title;
  final List<String> lines;
  final String hint;
  const _Success({required this.title, required this.lines, required this.hint});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Stack(
      children: [
        const Positioned.fill(child: Confetti()),
        _content(t, context),
      ],
    );
  }

  Widget _content(ThemeData t, BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: CircleAvatar(
                radius: 42,
                backgroundColor: t.colorScheme.primary,
                child: Icon(Icons.check_rounded, size: 50, color: t.colorScheme.onPrimary),
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(index: 2, child: Text(title, style: t.textTheme.headlineSmall)),
            const SizedBox(height: 10),
            for (var i = 0; i < lines.length; i++)
              FadeSlideIn(
                index: 3 + i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(lines[i], textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
                ),
              ),
            const SizedBox(height: 8),
            FadeSlideIn(
              index: 4 + lines.length,
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(onPressed: () => Navigator.pop(context), child: const Text('Готово')),
            ),
          ],
        ),
      ),
    );
  }
}
