import '../brand/brand_config.dart';
import '../brand/strings.dart';

String formatPrice(num? value) {
  if (value == null || !brand.features.showPrices) return S.priceOnRequest;
  return formatMoney(value);
}

/// Сумма в валюте бренда без учёта showPrices (для админки и итогов).
String formatMoney(num value) {
  final c = brand.currency;
  final fixed = value.toStringAsFixed(c.decimals);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => c.thousandsSeparator);
  final number = parts.length > 1 ? '$intPart,${parts[1]}' : intPart;
  return c.symbolAfter ? '$number ${c.symbol}' : '${c.symbol}$number';
}

String formatDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

String optionsLabel(Map<String, String> options) => options.values.join(' · ');
