import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../brand/brand_config.dart';
import '../brand/strings.dart';
import '../core/app_state.dart';
import '../core/features.dart';
import 'screens/shell.dart';
import 'system_prefs.dart';
import 'theme.dart';

/// Само приложение магазина с текущим брендом.
class StoreApp extends StatelessWidget {
  final AppState state;
  const StoreApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      // Тариф, тема и язык меняются на лету — приложение перестраивается.
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          state.activate();
          return SystemLook(
            premium: has(Feature.premiumMotion),
            child: MaterialApp(
              title: brand.appName,
              debugShowCheckedModeBanner: false,
              theme: buildTheme(Brightness.light),
              darkTheme: buildTheme(Brightness.dark),
              themeMode: state.themeMode,
              locale: Locale(S.lang),
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) {
                syncPageColor(Theme.of(context).colorScheme.surfaceContainer);
                return child!;
              },
              home: KeyedSubtree(key: ValueKey(state.revision), child: const Shell()),
            ),
          );
        },
      ),
    );
  }
}
