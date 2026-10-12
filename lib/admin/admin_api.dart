import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand/brand_config.dart';
import '../core/features.dart';
import '../core/rows.dart';

export '../core/rows.dart' show DbRow;

/// Всё, что админка делает с сервером. Реализация по умолчанию — Supabase;
/// для своего бэкенда достаточно реализовать этот интерфейс.
abstract class AdminApi {
  bool get configured;
  String? get email;
  Stream<void> get authChanges;

  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<bool> isAdmin();

  /// Таблицы каталога: categories, products, banners.
  Future<List<DbRow>> list(String table);
  Future<void> insert(String table, DbRow row);
  Future<void> update(String table, Object id, DbRow row);
  Future<void> delete(String table, Object id);

  Future<List<DbRow>> orders({String? status});
  Future<void> updateOrder(Object id, DbRow fields);

  /// Загружает картинку и возвращает публичный URL.
  Future<String> uploadImage(Uint8List bytes, String filename);

  /// Тариф, переключатели функций, промокоды, бонусы.
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);

  /// Все отзывы, включая ожидающие модерации.
  Future<List<DbRow>> reviews();
  Future<void> setReviewApproved(Object id, bool approved);
  Future<void> deleteReview(Object id);

  /// Демо-режим без сервера: данные хранятся в этом браузере.
  bool get isDemo => false;

  /// Сбросить демо-данные (только для демо-режима).
  Future<void> resetDemo() async {}
}

class SupabaseAdminApi implements AdminApi {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  bool get configured => brand.hasBackend;

  @override
  String? get email => configured ? _db.auth.currentUser?.email : null;

  @override
  Stream<void> get authChanges => configured ? _db.auth.onAuthStateChange : const Stream.empty();

  @override
  Future<void> signIn(String email, String password) => _db.auth.signInWithPassword(email: email.trim(), password: password);

  @override
  Future<void> signOut() => _db.auth.signOut();

  @override
  Future<bool> isAdmin() async => await _db.rpc('is_admin') == true;

  @override
  Future<List<DbRow>> list(String table) async {
    final q = _db.from(table).select();
    return switch (table) {
      'products' => await q.order('sort').order('created_at'),
      'categories' => await q.order('sort').order('title'),
      _ => await q.order('sort'),
    };
  }

  @override
  Future<void> insert(String table, DbRow row) => _db.from(table).insert(row);

  @override
  Future<void> update(String table, Object id, DbRow row) => _db.from(table).update(row).eq('id', id);

  @override
  Future<void> delete(String table, Object id) => _db.from(table).delete().eq('id', id);

  @override
  Future<List<DbRow>> orders({String? status}) async {
    var q = _db.from('orders').select();
    if (status != null) q = q.eq('status', status);
    return await q.order('created_at', ascending: false).limit(500);
  }

  @override
  Future<void> updateOrder(Object id, DbRow fields) => _db.from('orders').update(fields).eq('id', id);

  @override
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    final path = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
    final bucket = _db.storage.from('images');
    await bucket.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
    return bucket.getPublicUrl(path);
  }

  @override
  Future<AppSettings> getSettings() async {
    final row = await _db.from('app_settings').select('data').eq('id', 1).maybeSingle();
    final data = row?['data'];
    return data is Map ? AppSettings.fromJson(Map<String, dynamic>.from(data)) : const AppSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) => _db.from('app_settings').upsert({'id': 1, 'data': settings.toJson()});

  @override
  Future<List<DbRow>> reviews() async => await _db.from('reviews').select().order('created_at', ascending: false).limit(1000);

  @override
  Future<void> setReviewApproved(Object id, bool approved) => _db.from('reviews').update({'approved': approved}).eq('id', id);

  @override
  Future<void> deleteReview(Object id) => _db.from('reviews').delete().eq('id', id);

  @override
  bool get isDemo => false;

  @override
  Future<void> resetDemo() async {}
}
