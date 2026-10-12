import 'package:flutter/material.dart';

Color? parseHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (v == null) return null;
  return Color(hex.length <= 7 ? 0xFF000000 | v : v);
}

class Catalog {
  final List<Category> categories;
  final List<Product> products;
  final List<PromoBanner> banners;

  const Catalog({required this.categories, required this.products, required this.banners});

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
    categories: [for (final c in json['categories'] as List? ?? []) Category.fromJson(c)],
    products: [for (final p in json['products'] as List? ?? []) Product.fromJson(p)],
    banners: [for (final b in json['banners'] as List? ?? []) PromoBanner.fromJson(b)],
  );

  Category? category(String? id) => categories.where((c) => c.id == id).firstOrNull;
  Product? product(String id) => products.where((p) => p.id == id).firstOrNull;
  List<Product> inCategory(String id) => products.where((p) => p.categoryId == id).toList();
  List<Product> get featured => products.where((p) => p.featured).toList();
  List<Product> get onSale => products.where((p) => p.isOnSale).toList();

  List<Product> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return products
        .where(
          (p) =>
              p.title.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              (category(p.categoryId)?.title.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }
}

class Category {
  final String id;
  final String title;
  final String? icon;
  final String? image;
  final Color? color;

  const Category({required this.id, required this.title, this.icon, this.image, this.color});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'].toString(),
    title: j['title'] as String,
    icon: j['icon'] as String?,
    image: j['image'] as String?,
    color: parseHex(j['color'] as String?),
  );
}

class ProductOption {
  final String name;
  final List<String> values;

  const ProductOption({required this.name, required this.values});

  factory ProductOption.fromJson(Map<String, dynamic> j) =>
      ProductOption(name: j['name'] as String, values: [for (final v in j['values'] as List) v.toString()]);
}

class Product {
  final String id;
  final String categoryId;
  final String title;
  final num? price;
  final num? oldPrice;
  final String? unit;
  final List<String> images;
  final String description;
  final List<String> badges;
  final List<ProductOption> options;
  final Map<String, String> specs;
  final bool inStock;
  final bool featured;

  const Product({
    required this.id,
    required this.categoryId,
    required this.title,
    this.price,
    this.oldPrice,
    this.unit,
    this.images = const [],
    this.description = '',
    this.badges = const [],
    this.options = const [],
    this.specs = const {},
    this.inStock = true,
    this.featured = false,
  });

  bool get isOnSale => price != null && oldPrice != null && oldPrice! > price!;
  int get discountPercent => isOnSale ? ((1 - price! / oldPrice!) * 100).round() : 0;
  String? get image => images.firstOrNull;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'].toString(),
    categoryId: j['categoryId'].toString(),
    title: j['title'] as String,
    price: j['price'] as num?,
    oldPrice: j['oldPrice'] as num?,
    unit: j['unit'] as String?,
    images: [for (final i in j['images'] as List? ?? []) i.toString()],
    description: j['description'] as String? ?? '',
    badges: [for (final b in j['badges'] as List? ?? []) b.toString()],
    options: [for (final o in j['options'] as List? ?? []) ProductOption.fromJson(o)],
    specs: {for (final e in (j['specs'] as Map? ?? {}).entries) e.key.toString(): e.value.toString()},
    inStock: j['inStock'] as bool? ?? true,
    featured: j['featured'] as bool? ?? false,
  );
}

class PromoBanner {
  final String title;
  final String? subtitle;
  final String? image;
  final Color? color;
  final String? categoryId;
  final String? productId;

  const PromoBanner({required this.title, this.subtitle, this.image, this.color, this.categoryId, this.productId});

  factory PromoBanner.fromJson(Map<String, dynamic> j) => PromoBanner(
    title: j['title'] as String,
    subtitle: j['subtitle'] as String?,
    image: j['image'] as String?,
    color: parseHex(j['color'] as String?),
    categoryId: j['categoryId'] as String?,
    productId: j['productId'] as String?,
  );
}

/// Позиция в корзине. Один товар с разными опциями — разные позиции.
class CartLine {
  final String productId;
  final Map<String, String> options;
  int quantity;

  CartLine({required this.productId, this.options = const {}, this.quantity = 1});

  String get key => '$productId|${(options.entries.map((e) => '${e.key}=${e.value}').toList()..sort()).join(',')}';

  Map<String, dynamic> toJson() => {'productId': productId, 'options': options, 'quantity': quantity};

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
    productId: j['productId'] as String,
    options: Map<String, String>.from(j['options'] as Map? ?? {}),
    quantity: j['quantity'] as int? ?? 1,
  );
}

/// Снимок позиции в заказе — хранит название и цену на момент покупки.
class OrderLine {
  final String productId;
  final String title;
  final Map<String, String> options;
  final num price;
  final int quantity;

  const OrderLine({
    required this.productId,
    required this.title,
    required this.options,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'title': title,
    'options': options,
    'price': price,
    'quantity': quantity,
  };

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
    productId: j['productId'] as String,
    title: j['title'] as String,
    options: Map<String, String>.from(j['options'] as Map? ?? {}),
    price: j['price'] as num,
    quantity: j['quantity'] as int,
  );
}

class Customer {
  final String name;
  final String phone;
  final String address;

  const Customer({this.name = '', this.phone = '', this.address = ''});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'address': address};

  factory Customer.fromJson(Map<String, dynamic> j) =>
      Customer(name: j['name'] as String? ?? '', phone: j['phone'] as String? ?? '', address: j['address'] as String? ?? '');
}

class Order {
  final String id;
  final DateTime createdAt;
  final List<OrderLine> lines;
  final Customer customer;
  final bool isDelivery;
  final String payment;
  final String comment;
  final num subtotal;
  final num deliveryFee;
  final num discount;
  final String? promoCode;
  final num bonusSpent;
  final num bonusEarned;
  final String? deliverySlot;

  const Order({
    required this.id,
    required this.createdAt,
    required this.lines,
    required this.customer,
    required this.isDelivery,
    required this.payment,
    required this.comment,
    required this.subtotal,
    required this.deliveryFee,
    this.discount = 0,
    this.promoCode,
    this.bonusSpent = 0,
    this.bonusEarned = 0,
    this.deliverySlot,
  });

  num get total => subtotal - discount - bonusSpent + deliveryFee;

  Order withId(String newId) => Order(
    id: newId,
    createdAt: createdAt,
    lines: lines,
    customer: customer,
    isDelivery: isDelivery,
    payment: payment,
    comment: comment,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    discount: discount,
    promoCode: promoCode,
    bonusSpent: bonusSpent,
    bonusEarned: bonusEarned,
    deliverySlot: deliverySlot,
  );

  int get itemCount => lines.fold(0, (s, l) => s + l.quantity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'lines': [for (final l in lines) l.toJson()],
    'customer': customer.toJson(),
    'isDelivery': isDelivery,
    'payment': payment,
    'comment': comment,
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'discount': discount,
    'promoCode': promoCode,
    'bonusSpent': bonusSpent,
    'bonusEarned': bonusEarned,
    'deliverySlot': deliverySlot,
  };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    lines: [for (final l in j['lines'] as List) OrderLine.fromJson(l)],
    customer: Customer.fromJson(j['customer'] as Map<String, dynamic>),
    isDelivery: j['isDelivery'] as bool,
    payment: j['payment'] as String,
    comment: j['comment'] as String? ?? '',
    subtotal: j['subtotal'] as num,
    deliveryFee: j['deliveryFee'] as num,
    discount: j['discount'] as num? ?? 0,
    promoCode: j['promoCode'] as String?,
    bonusSpent: j['bonusSpent'] as num? ?? 0,
    bonusEarned: j['bonusEarned'] as num? ?? 0,
    deliverySlot: j['deliverySlot'] as String?,
  );
}

class Review {
  final String id;
  final String productId;
  final String name;
  final int rating;
  final String text;
  final DateTime createdAt;
  final bool approved;

  const Review({
    required this.id,
    required this.productId,
    required this.name,
    required this.rating,
    required this.text,
    required this.createdAt,
    this.approved = true,
  });

  /// Строка таблицы reviews (Supabase / локальная база).
  Map<String, dynamic> toRow() => {
    'id': id,
    'product_id': productId,
    'name': name,
    'rating': rating,
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'approved': approved,
  };

  factory Review.fromRow(Map<String, dynamic> r) => Review(
    id: r['id'].toString(),
    productId: r['product_id'].toString(),
    name: r['name'] as String? ?? '',
    rating: (r['rating'] as num? ?? 5).toInt(),
    text: r['text'] as String? ?? '',
    createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
    approved: r['approved'] as bool? ?? true,
  );
}
