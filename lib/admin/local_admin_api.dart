import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/features.dart';
import '../core/local_store.dart';
import 'admin_api.dart';

/// Админка без сервера: работает с [LocalStore] — той же базой, из которой
/// читает приложение. Поэтому любые правки сразу видны в демо.
class LocalAdminApi implements AdminApi {
  final LocalStore store;
  LocalAdminApi(this.store);

  @override
  bool get configured => true;

  @override
  bool get isDemo => true;

  @override
  String? get email => 'demo@anteyko.com';

  @override
  Stream<void> get authChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> isAdmin() async => true;

  List<DbRow> _table(String t) => switch (t) {
    'categories' => store.categories,
    'products' => store.products,
    'banners' => store.banners,
    _ => throw ArgumentError('Неизвестная таблица $t'),
  };

  // Копии строк: админка не должна править базу напрямую в обход save().
  List<DbRow> _copy(List<DbRow> rows) => [for (final r in rows) jsonDecode(jsonEncode(r)) as DbRow];

  @override
  Future<List<DbRow>> list(String table) async {
    await store.ensure();
    final rows = _copy(_table(table));
    rows.sort((a, b) => ((a['sort'] as num?) ?? 0).compareTo((b['sort'] as num?) ?? 0));
    return rows;
  }

  @override
  Future<void> insert(String table, DbRow row) async {
    await store.ensure();
    final t = _table(table);
    final id = row['id'] ?? '${table[0]}${DateTime.now().microsecondsSinceEpoch}';
    if (t.any((r) => r['id'] == id)) throw Exception('Запись с кодом «$id» уже есть');
    t.add({
      ...row,
      'id': id,
      if (table == 'products') 'created_at': DateTime.now().toIso8601String(),
      if (table == 'banners' && row['active'] == null) 'active': true,
    });
    await store.save();
  }

  @override
  Future<void> update(String table, Object id, DbRow row) async {
    await store.ensure();
    _table(table).firstWhere((r) => r['id'] == id).addAll(row);
    await store.save();
  }

  @override
  Future<void> delete(String table, Object id) async {
    await store.ensure();
    _table(table).removeWhere((r) => r['id'] == id);
    await store.save();
  }

  @override
  Future<List<DbRow>> orders({String? status}) async {
    await store.ensure();
    return _copy(store.orders.where((o) => status == null || o['status'] == status).toList());
  }

  @override
  Future<void> updateOrder(Object id, DbRow fields) async {
    await store.ensure();
    store.orders.firstWhere((o) => '${o['id']}' == '$id').addAll(fields);
    await store.save();
  }

  /// Без сервера картинка хранится прямо в базе (data:-ссылка), поэтому — до 400 КБ.
  @override
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    if (bytes.length > 400 * 1024) {
      throw Exception('В демо-режиме картинка до 400 КБ. С сервером ограничений нет.');
    }
    final ext = filename.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  @override
  Future<AppSettings> getSettings() async {
    await store.ensure();
    return store.settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    store.settings = settings;
    await store.save();
  }

  @override
  Future<List<DbRow>> reviews() async {
    await store.ensure();
    return _copy(store.reviews);
  }

  @override
  Future<void> setReviewApproved(Object id, bool approved) async {
    store.reviews.firstWhere((r) => r['id'] == id)['approved'] = approved;
    await store.save();
  }

  @override
  Future<void> deleteReview(Object id) async {
    store.reviews.removeWhere((r) => r['id'] == id);
    await store.save();
  }

  @override
  Future<void> resetDemo() => store.reset();
}
