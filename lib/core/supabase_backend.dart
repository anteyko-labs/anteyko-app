import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand/brand_config.dart';
import 'backend.dart';
import 'features.dart';
import 'models.dart';
import 'order_service.dart';
import 'rows.dart';

/// Подключение к Supabase, если в brand_config указаны supabaseUrl и supabaseKey.
Future<void> initBackend() async {
  if (!brand.hasBackend) return;
  await Supabase.initialize(url: brand.supabaseUrl!, publishableKey: brand.supabaseKey!);
}

SupabaseClient get db => Supabase.instance.client;

/// Сервер на Supabase (таблицы и права — supabase/schema.sql).
class SupabaseBackend extends ShopBackend {
  @override
  Future<Catalog> load() async {
    final (categories, products, banners) = await (
      db.from('categories').select().order('sort').order('title'),
      db.from('products').select().eq('active', true).order('sort').order('created_at'),
      db.from('banners').select().eq('active', true).order('sort'),
    ).wait;
    return catalogFromRows(categories, products, banners);
  }

  @override
  Future<AppSettings> loadSettings() async {
    final row = await db.from('app_settings').select('data').eq('id', 1).maybeSingle();
    final data = row?['data'];
    return data is Map ? AppSettings.fromJson(Map<String, dynamic>.from(data)) : const AppSettings();
  }

  @override
  Future<List<Review>> loadReviews() async {
    final rows = await db.from('reviews').select().eq('approved', true).order('created_at', ascending: false).limit(1000);
    return [for (final r in rows) Review.fromRow(r)];
  }

  @override
  Future<void> addReview(Review review) => db.from('reviews').insert({
    'product_id': review.productId,
    'name': review.name,
    'rating': review.rating,
    'text': review.text,
  });

  /// Заказ сохраняется функцией place_order: она пересчитывает цены и проверяет промокод,
  /// затем, если настроено, дублируется в мессенджер.
  @override
  Future<String?> submit(Order order) async {
    final id = await db.rpc(
      'place_order',
      params: {
        'p': {
          'customer': order.customer.toJson(),
          'isDelivery': order.isDelivery,
          'payment': order.payment,
          'comment': order.comment,
          'deliveryFee': order.deliveryFee,
          'deliverySlot': order.deliverySlot,
          'promoCode': order.promoCode,
          'bonusSpent': order.bonusSpent,
          'lines': [
            for (final l in order.lines) {'productId': l.productId, 'options': l.options, 'quantity': l.quantity},
          ],
        },
      },
    );
    final serverId = id.toString();
    if (brand.checkout.orderChannel != OrderChannel.none) {
      await const MessengerOrderSubmitter().submit(order.withId(serverId));
    }
    return serverId;
  }
}
