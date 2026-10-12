import 'package:flutter/material.dart';

import 'admin/admin_api.dart';
import 'admin/admin_app.dart';
import 'brand/brand_config.dart';
import 'core/app_state.dart';
import 'admin/local_admin_api.dart';
import 'core/local_store.dart';
import 'core/supabase_backend.dart';
import 'showcase/showcase_app.dart';
import 'ui/store_app.dart';
import 'ui/system_prefs.dart';

export 'ui/store_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackend();
  // Прозрачность и контраст из настроек iPhone / браузера.
  await systemPrefs.init();

  // Веб-админка: <адрес приложения>/#/admin. Без Supabase — демо-режим в этом браузере.
  if (isAdminRoute) {
    return runApp(AdminApp(api: brand.hasBackend ? SupabaseAdminApi() : LocalAdminApi(localStoreFor(brand))));
  }

  // Витрина студии с выбором демо.
  if (showcaseMode) return runApp(const ShowcaseApp());

  // Сборка для клиента.
  final state = AppState(backend: brand.hasBackend ? SupabaseBackend() : localStoreFor(brand))..init();
  runApp(StoreApp(state: state));
}

bool get isAdminRoute {
  final u = Uri.base;
  return u.fragment.startsWith('/admin') || u.path.endsWith('/admin');
}
