import 'models.dart';

typedef DbRow = Map<String, dynamic>;

/// Строки таблиц (snake_case, как в Supabase и локальной базе) ↔ формат catalog.json.

DbRow categoryFromRow(DbRow r) => {
  'id': r['id'],
  'title': r['title'],
  'icon': r['icon'],
  'image': r['image'],
  'color': r['color'],
};

DbRow productFromRow(DbRow r) => {
  'id': r['id'],
  'categoryId': r['category_id'] ?? '',
  'title': r['title'],
  'price': r['price'],
  'oldPrice': r['old_price'],
  'unit': r['unit'],
  'images': r['images'] ?? const [],
  'description': r['description'] ?? '',
  'badges': r['badges'] ?? const [],
  'options': r['options'] ?? const [],
  'specs': r['specs'] ?? const {},
  'inStock': r['in_stock'] ?? true,
  'featured': r['featured'] ?? false,
};

DbRow bannerFromRow(DbRow r) => {
  'title': r['title'],
  'subtitle': r['subtitle'],
  'image': r['image'],
  'color': r['color'],
  'categoryId': r['category_id'],
  'productId': r['product_id'],
};

DbRow categoryToRow(DbRow c, int sort) => {
  'id': c['id'],
  'title': c['title'],
  'icon': c['icon'],
  'image': c['image'],
  'color': c['color'],
  'sort': sort,
};

DbRow productToRow(DbRow p, int sort) => {
  'id': p['id'],
  'category_id': p['categoryId'],
  'title': p['title'],
  'price': p['price'],
  'old_price': p['oldPrice'],
  'unit': p['unit'],
  'images': p['images'] ?? const [],
  'description': p['description'] ?? '',
  'badges': p['badges'] ?? const [],
  'options': p['options'] ?? const [],
  'specs': p['specs'] ?? const {},
  'in_stock': p['inStock'] ?? true,
  'featured': p['featured'] ?? false,
  'active': true,
  'sort': sort,
  'created_at': DateTime.now().toIso8601String(),
};

DbRow bannerToRow(DbRow b, int sort) => {
  'id': 'b$sort',
  'title': b['title'],
  'subtitle': b['subtitle'],
  'image': b['image'],
  'color': b['color'],
  'category_id': b['categoryId'],
  'product_id': b['productId'],
  'active': true,
  'sort': sort,
};

int _bySort(DbRow a, DbRow b) => ((a['sort'] as num?) ?? 0).compareTo((b['sort'] as num?) ?? 0);

/// Каталог для приложения: только опубликованные товары и активные баннеры, по порядку.
Catalog catalogFromRows(List<DbRow> categories, List<DbRow> products, List<DbRow> banners) => Catalog.fromJson({
  'categories': ([...categories]..sort(_bySort)).map(categoryFromRow).toList(),
  'products': ([...products.where((p) => p['active'] != false)]..sort(_bySort)).map(productFromRow).toList(),
  'banners': ([...banners.where((b) => b['active'] != false)]..sort(_bySort)).map(bannerFromRow).toList(),
});

/// Заказ из приложения → строка таблицы orders.
DbRow orderToRow(Order o, {required String id}) => {
  'id': id,
  'created_at': o.createdAt.toUtc().toIso8601String(),
  'status': 'new',
  'customer_name': o.customer.name,
  'customer_phone': o.customer.phone,
  'address': o.customer.address,
  'is_delivery': o.isDelivery,
  'payment': o.payment,
  'comment': o.comment,
  'lines': [for (final l in o.lines) l.toJson()],
  'subtotal': o.subtotal,
  'delivery_fee': o.deliveryFee,
  'discount': o.discount,
  'promo_code': o.promoCode,
  'bonus_spent': o.bonusSpent,
  'delivery_slot': o.deliverySlot,
  'total': o.total,
  'admin_note': '',
};
