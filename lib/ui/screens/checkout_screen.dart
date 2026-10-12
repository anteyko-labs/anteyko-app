import 'package:flutter/material.dart';

import '../../brand/brand_config.dart';
import '../../brand/strings.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/order_service.dart';
import '../../core/features.dart';
import '../motion.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import 'cart_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _comment = TextEditingController();
  late bool _isDelivery = brand.checkout.delivery;
  late PaymentMethod _payment = brand.checkout.paymentMethods.first;
  bool _sending = false;
  bool _prefilled = false;
  final _promo = TextEditingController();
  String? _appliedPromo;
  String? _promoError;
  bool _useBonuses = false;
  String? _slot;

  /// Интервалы доставки: «как можно скорее» + ближайшие окна по 2 часа.
  List<String> get _slots {
    final now = DateTime.now();
    final out = [S.asap];
    for (var h = 10; h <= 20; h += 2) {
      if (h > now.hour + 1) out.add('${S.lang == 'en' ? 'Today' : 'Сегодня'} $h:00–${h + 2}:00');
    }
    for (var h = 10; h <= 18; h += 4) {
      out.add('${S.lang == 'en' ? 'Tomorrow' : 'Завтра'} $h:00–${h + 2}:00');
    }
    return out;
  }

  void _applyPromo(AppState state) {
    final code = _promo.text.trim();
    final d = state.promoDiscount(code);
    setState(() {
      _appliedPromo = d > 0 ? code.toUpperCase() : null;
      _promoError = d > 0 ? null : S.promoInvalid;
    });
    if (d > 0) FocusScope.of(context).unfocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final c = AppState.of(context).customer;
    _name.text = c.name;
    _phone.text = c.phone;
    _address.text = c.address;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _comment, _promo]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? S.required : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    final state = AppState.of(context);
    try {
      final order = await state.placeOrder(
        customer: Customer(name: _name.text.trim(), phone: _phone.text.trim(), address: _address.text.trim()),
        isDelivery: _isDelivery,
        payment: _payment.name,
        comment: _comment.text.trim(),
        promoCode: _appliedPromo,
        bonusToSpend: _useBonuses ? state.maxBonusSpend(discount: state.promoDiscount(_appliedPromo)) : 0,
        deliverySlot: _slot ?? S.asap,
      );
      if (!mounted) return;
      Navigator.of(context)
          .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)), (r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final c = brand.checkout;
    final fee = state.deliveryFeeFor(isDelivery: _isDelivery);
    final discount = state.promoDiscount(_appliedPromo);
    final maxBonus = state.maxBonusSpend(discount: discount);
    final bonus = _useBonuses ? maxBonus : 0;
    final total = state.subtotal - discount - bonus + fee;
    final earn = state.bonusEarnedFor(state.subtotal - discount - bonus);
    final t = Theme.of(context);
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(title: Text(S.checkout)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: S.name),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            gap,
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: S.phone),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            if (c.delivery && c.pickup) ...[
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(S.delivery), icon: const Icon(Icons.local_shipping_outlined)),
                  ButtonSegment(value: false, label: Text(S.pickup), icon: const Icon(Icons.storefront_outlined)),
                ],
                selected: {_isDelivery},
                onSelectionChanged: (s) => setState(() => _isDelivery = s.first),
              ),
            ],
            if (_isDelivery) ...[
              gap,
              TextFormField(
                controller: _address,
                decoration: InputDecoration(labelText: S.address),
                maxLines: 2,
                minLines: 1,
                validator: _required,
              ),
              if (has(Feature.deliverySlots)) ...[
                const SizedBox(height: 18),
                Text(S.deliveryTime, style: t.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sl in _slots)
                      ChoiceChip(
                        label: Text(sl),
                        selected: (_slot ?? S.asap) == sl,
                        onSelected: (_) => setState(() => _slot = sl),
                      ),
                  ],
                ),
              ],
            ] else if (brand.contacts.address != null) ...[
              gap,
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(brand.contacts.address!),
                subtitle: brand.contacts.workHours != null ? Text(brand.contacts.workHours!) : null,
              ),
            ],
            if (c.paymentMethods.length > 1) ...[
              const SizedBox(height: 20),
              Text(S.payment, style: t.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in c.paymentMethods)
                    ChoiceChip(
                      label: Text(paymentLabel(m.name)),
                      selected: _payment == m,
                      onSelected: (_) => setState(() => _payment = m),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _comment,
              decoration: InputDecoration(labelText: S.comment),
              maxLines: 3,
              minLines: 1,
            ),
            if (has(Feature.promoCodes)) ...[
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promo,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: S.promoCode,
                        hintText: 'WELCOME10',
                        errorText: _promoError,
                        prefixIcon: const Icon(Icons.confirmation_number_outlined),
                        suffixIcon: _appliedPromo == null ? null : const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                      ),
                      onChanged: (_) => setState(() {
                        _promoError = null;
                        _appliedPromo = null;
                      }),
                      onSubmitted: (_) => _applyPromo(state),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: FilledButton.tonal(onPressed: () => _applyPromo(state), child: Text(S.apply)),
                  ),
                ],
              ),
            ],
            if (has(Feature.loyalty) && state.bonusBalance > 0) ...[
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.loyalty_outlined),
                  title: Text('${S.payWithBonuses}: ${formatMoney(maxBonus)}'),
                  subtitle: Text('${S.bonusBalance}: ${formatMoney(state.bonusBalance)}'),
                  value: _useBonuses && maxBonus > 0,
                  onChanged: maxBonus > 0 ? (v) => setState(() => _useBonuses = v) : null,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SummaryRow(S.subtotal, formatPrice(state.subtotal)),
            if (discount > 0) SummaryRow('${S.discount} · $_appliedPromo', '−${formatMoney(discount)}'),
            if (bonus > 0) SummaryRow(S.bonuses, '−${formatMoney(bonus)}'),
            if (_isDelivery) SummaryRow(S.delivery, fee == 0 ? S.free : formatPrice(fee)),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(S.total, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                AnimatedMoney(total, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            if (earn > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${formatMoney(earn)} — ${S.willEarn.toLowerCase()}',
                  style: TextStyle(color: t.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _sending || state.cart.isEmpty ? null : _submit,
          child: _sending
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(S.placeOrder),
        ),
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final Order order;
  const OrderSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: Confetti(count: 110)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: t.colorScheme.primary,
                      child: Icon(Icons.check_rounded, size: 56, color: t.colorScheme.onPrimary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    index: 3,
                    child: Text(S.orderPlaced, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 4,
                    child: Text('${S.order} #${order.id} · ${formatPrice(order.total)}', style: t.textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 5,
                    child: Text(
                      S.orderPlacedHint,
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const Spacer(),
                  FadeSlideIn(
                    index: 6,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.toHome)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
