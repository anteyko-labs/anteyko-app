import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/order_service.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';
import '../../core/features.dart';

/// Вкладка «Ещё»: о компании, контакты, история заказов.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final t = Theme.of(context);
    final c = brand.contacts;

    return Scaffold(
      appBar: AppBar(title: Text(S.more)),
      body: ListView(
        padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandLogo(size: 26),
                    const SizedBox(height: 6),
                    Text(brand.tagline, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
          if (has(Feature.loyalty))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: FadeSlideIn(
                child: _LoyaltyCard(balance: state.bonusBalance, percent: state.settings.loyaltyPercent),
              ),
            ),
          if (has(Feature.orderHistory)) ...[
            _Header(S.orders),
            if (state.orders.isEmpty)
              ListTile(leading: const Icon(Icons.receipt_long_outlined), title: Text(S.noOrders))
            else
              for (final o in state.orders.take(20))
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Row(
                    children: [
                      Text('${S.order} #${o.id}'),
                      if (state.statuses[o.id] case final st?) ...[const SizedBox(width: 8), _StatusPill(st)],
                    ],
                  ),
                  subtitle: Text('${formatDate(o.createdAt)} · ${o.itemCount} ${S.pcs}'),
                  trailing: Text(formatPrice(o.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => _showOrder(context, o),
                ),
          ],
          if (has(Feature.themeSwitch) || has(Feature.languages)) ...[
            _Header(S.settings),
            if (has(Feature.themeSwitch))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.appearance, style: t.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(S.themeSystem),
                          icon: const Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(S.themeLight),
                          icon: const Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(S.themeDark),
                          icon: const Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {state.themeMode},
                      onSelectionChanged: (v) => state.setThemeChoice(v.first),
                    ),
                  ],
                ),
              ),
            if (has(Feature.languages))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.language, style: t.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ru', label: Text('Русский')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {S.lang},
                      onSelectionChanged: (v) => state.setLanguage(v.first),
                    ),
                  ],
                ),
              ),
          ],
          _Header(S.contacts),
          if (c.phone != null) ListTile(leading: const Icon(Icons.call_outlined), title: Text(c.phone!), onTap: callStore),
          if (c.whatsapp != null)
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () => openLink('https://wa.me/${c.whatsapp}'),
            ),
          if (c.telegram != null)
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: const Text('Telegram'),
              subtitle: Text('@${c.telegram}'),
              onTap: () => openLink('https://t.me/${c.telegram}'),
            ),
          if (c.instagram != null)
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Instagram'),
              subtitle: Text('@${c.instagram}'),
              onTap: () => openLink('https://instagram.com/${c.instagram}'),
            ),
          if (c.email != null)
            ListTile(leading: const Icon(Icons.mail_outline), title: Text(c.email!), onTap: () => openLink('mailto:${c.email}')),
          if (c.address != null)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(c.address!),
              trailing: c.mapUrl != null ? const Icon(Icons.open_in_new, size: 18) : null,
              onTap: c.mapUrl != null ? () => openLink(c.mapUrl!) : null,
            ),
          if (c.workHours != null)
            ListTile(leading: const Icon(Icons.schedule), title: Text(c.workHours!), subtitle: Text(S.workHours)),
          _Header(S.about),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(brand.about, style: t.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }

  void _showOrder(BuildContext context, Order o) {
    final state = AppState.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${S.order} #${o.id}', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(formatDate(o.createdAt), style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              for (final l in o.lines)
                SummaryRow(
                  '${l.title}${l.options.isEmpty ? '' : ' (${optionsLabel(l.options)})'} × ${l.quantity}',
                  formatPrice(l.price * l.quantity),
                ),
              const Divider(height: 20),
              if (o.discount > 0) SummaryRow(S.discount, '−${formatMoney(o.discount)}'),
              if (o.bonusSpent > 0) SummaryRow(S.bonuses, '−${formatMoney(o.bonusSpent)}'),
              SummaryRow(o.isDelivery ? S.delivery : S.pickup, o.deliveryFee == 0 ? S.free : formatPrice(o.deliveryFee)),
              SummaryRow(S.total, formatPrice(o.total), bold: true),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    state.repeatOrder(o);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.inCart)));
                  },
                  child: Text(S.repeatOrder),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (bg, fg) = switch (status) {
      'done' => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
      'cancelled' => (t.colorScheme.surfaceContainerHighest, t.colorScheme.onSurfaceVariant),
      'delivering' => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      _ => (t.colorScheme.primaryContainer, t.colorScheme.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        S.status(status),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Бонусная карта: баланс досчитывается, фон «дышит».
class _LoyaltyCard extends StatelessWidget {
  final num balance;
  final int percent;
  const _LoyaltyCard({required this.balance, required this.percent});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(brand.cornerRadius.clamp(8, 24) + 4),
      child: Stack(
        children: [
          Positioned.fill(
            child: Breathing(
              period: const Duration(seconds: 6),
              builder: (_, v) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + v * 0.6, -1),
                    end: Alignment(1, 1 - v * 0.6),
                    colors: [c.primary, shiftHue(c.primary, 35, lighten: 0.08)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(right: -30, top: -30, child: Icon(Icons.loyalty, size: 150, color: c.onPrimary.withValues(alpha: 0.12))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.bonusBalance, style: TextStyle(color: c.onPrimary.withValues(alpha: 0.85))),
                const SizedBox(height: 6),
                AnimatedMoney(
                  balance,
                  style: TextStyle(color: c.onPrimary, fontSize: 32, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('$percent% ${S.cashback}', style: TextStyle(color: c.onPrimary.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
