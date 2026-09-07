import 'package:coach_app/app/router/app_router.dart';
import 'package:coach_app/app/theme/theme.dart';
import 'package:coach_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class App extends StatefulWidget {
  const App({this.router, super.key});

  /// Overridden in tests to start on a given route.
  final GoRouter? router;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Dark is the design's default; M4 hands this over to SettingsCubit.
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
