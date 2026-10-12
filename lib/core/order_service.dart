import 'package:url_launcher/url_launcher.dart';

import '../brand/brand_config.dart';
import '../brand/strings.dart';
import 'format.dart';
import 'models.dart';

/// Отправка заказа. Возвращает номер заказа на сервере (если он есть).
/// Готовые варианты: MessengerOrderSubmitter и SupabaseOrderSubmitter.
/// Для своего API реализуйте этот интерфейс и передайте в AppState (main.dart).
abstract class OrderSubmitter {
  Future<String?> submit(Order order);
}

class MessengerOrderSubmitter implements OrderSubmitter {
  const MessengerOrderSubmitter();

  @override
  Future<String?> submit(Order order) async {
    final text = orderToText(order);
    final c = brand.contacts;
    final Uri? uri = switch (brand.checkout.orderChannel) {
      OrderChannel.whatsapp when c.whatsapp != null => Uri.parse('https://wa.me/${c.whatsapp}?text=${Uri.encodeComponent(text)}'),
      OrderChannel.telegram when c.telegram != null => Uri.parse('https://t.me/${c.telegram}?text=${Uri.encodeComponent(text)}'),
      OrderChannel.email when c.email != null => Uri(
        scheme: 'mailto',
        path: c.email,
        query:
            'subject=${Uri.encodeComponent('${S.order} #${order.id}')}'
            '&body=${Uri.encodeComponent(text)}',
      ),
      _ => null,
    };
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return null;
  }
}

String paymentLabel(String method) => switch (method) {
  'card' => S.card,
  'transfer' => S.transfer,
  _ => S.cash,
};

String orderToText(Order o) {
  final b = StringBuffer()
    ..writeln('${S.order} #${o.id} — ${brand.appName}')
    ..writeln();
  for (final l in o.lines) {
    final opts = l.options.isEmpty ? '' : ' (${optionsLabel(l.options)})';
    b.writeln('• ${l.title}$opts × ${l.quantity} = ${formatPrice(l.price * l.quantity)}');
  }
  b
    ..writeln()
    ..writeln('${S.subtotal}: ${formatPrice(o.subtotal)}')
    ..writeln(
      '${o.isDelivery ? S.delivery : S.pickup}: '
      '${o.deliveryFee == 0 ? S.free : formatPrice(o.deliveryFee)}',
    )
    ..writeln('${S.total}: ${formatPrice(o.total)}')
    ..writeln()
    ..writeln('${S.name}: ${o.customer.name}')
    ..writeln('${S.phone}: ${o.customer.phone}');
  if (o.isDelivery) b.writeln('${S.address}: ${o.customer.address}');
  b.writeln('${S.payment}: ${paymentLabel(o.payment)}');
  if (o.comment.isNotEmpty) b.writeln('${S.comment}: ${o.comment}');
  return b.toString();
}

Future<void> openLink(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

Future<void> callStore() async {
  final phone = brand.contacts.phone;
  if (phone != null) await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
}

/// «Связаться» из режима витрины: WhatsApp → Telegram → звонок.
Future<void> contactStore({String? about}) async {
  final c = brand.contacts;
  final text = about == null ? '' : Uri.encodeComponent('${brand.appName}: $about');
  if (c.whatsapp != null) return openLink('https://wa.me/${c.whatsapp}?text=$text');
  if (c.telegram != null) return openLink('https://t.me/${c.telegram}');
  return callStore();
}
