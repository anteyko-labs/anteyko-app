import 'dart:async';
import 'dart:typed_data';

import 'package:app/admin/admin_api.dart';
import 'package:app/core/features.dart';

/// AdminApi в памяти — для тестов админки без Supabase.
class FakeAdminApi implements AdminApi {
  final _auth = StreamController<void>.broadcast();
  String? _email;
  final bool admin;
  final Map<String, List<DbRow>> tables;
  final List<DbRow> orderRows;
  final calls = <String>[];

  FakeAdminApi({this.admin = true, String? signedInAs, Map<String, List<DbRow>>? tables, List<DbRow>? orders})
    : _email = signedInAs,
      tables = tables ?? {'categories': [], 'products': [], 'banners': []},
      orderRows = orders ?? [];

  @override
  bool get configured => true;
  @override
  String? get email => _email;
  @override
  Stream<void> get authChanges => _auth.stream;

  @override
  Future<void> signIn(String email, String password) async {
    if (password != 'secret') throw Exception('Invalid login credentials');
    _email = email;
    _auth.add(null);
  }

  @override
  Future<void> signOut() async {
    _email = null;
    _auth.add(null);
  }

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<DbRow>> list(String table) async => [for (final r in tables[table]!) Map.of(r)];

  @override
  Future<void> insert(String table, DbRow row) async {
    calls.add('insert $table');
    tables[table]!.add({'id': row['id'] ?? 'new${tables[table]!.length}', ...row});
  }

  @override
  Future<void> update(String table, Object id, DbRow row) async {
    calls.add('update $table $id');
    tables[table]!.firstWhere((r) => r['id'] == id).addAll(row);
  }

  @override
  Future<void> delete(String table, Object id) async {
    calls.add('delete $table $id');
    tables[table]!.removeWhere((r) => r['id'] == id);
  }

  @override
  Future<List<DbRow>> orders({String? status}) async =>
      orderRows.where((o) => status == null || o['status'] == status).map(Map.of).toList();

  @override
  Future<void> updateOrder(Object id, DbRow fields) async {
    calls.add('order $id ${fields['status']}');
    orderRows.firstWhere((o) => o['id'] == id).addAll(fields);
  }

  @override
  Future<String> uploadImage(Uint8List bytes, String filename) async => 'https://example.com/$filename';

  AppSettings settings = const AppSettings();
  final reviewRows = <DbRow>[];

  @override
  Future<AppSettings> getSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings s) async {
    calls.add('settings ${s.plan.name}');
    settings = s;
  }

  @override
  Future<List<DbRow>> reviews() async => [for (final r in reviewRows) Map.of(r)];

  @override
  Future<void> setReviewApproved(Object id, bool approved) async =>
      reviewRows.firstWhere((r) => r['id'] == id)['approved'] = approved;

  @override
  Future<void> deleteReview(Object id) async => reviewRows.removeWhere((r) => r['id'] == id);

  @override
  bool get isDemo => false;

  @override
  Future<void> resetDemo() async {}
}

List<DbRow> sampleOrders() => [
  {
    'id': 42,
    'created_at': '2026-10-10T12:30:00Z',
    'status': 'new',
    'customer_name': 'Айгерим',
    'customer_phone': '+996 555 123 456',
    'address': 'ул. Киевская, 10',
    'is_delivery': true,
    'payment': 'card',
    'comment': 'Позвонить заранее',
    'lines': [
      {
        'productId': 'p1',
        'title': 'Футболка',
        'options': {'Размер': 'M'},
        'price': 890,
        'quantity': 2,
      },
    ],
    'subtotal': 1780,
    'delivery_fee': 200,
    'total': 1980,
    'admin_note': '',
  },
];
