import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class SehatIdApp extends StatelessWidget {
  const SehatIdApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();

    return MaterialApp.router(
      title: 'SehatID',
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
      locale: lang.locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      // Drive RTL app-wide when Urdu is selected.
      builder: (context, child) => Directionality(
        textDirection: lang.direction,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Provider scope shared by the whole app.
class AppProviders extends StatelessWidget {
  final Widget child;
  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ],
      child: child,
    );
  }
}
