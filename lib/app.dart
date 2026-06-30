import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/record_controller.dart';
import 'controllers/card_controller.dart';
import 'controllers/chat_controller.dart';
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
      title: 'HayaatID',
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
        ChangeNotifierProvider(create: (_) => AuthController()..loadSession()),
        ChangeNotifierProxyProvider<AuthController, RecordController>(
          create: (_) => RecordController(),
          update: (_, auth, record) {
            final rec = record ?? RecordController();
            // Defer so we never call notifyListeners() during the build phase.
            if (auth.isAuthenticated) {
              if (!rec.loaded && !rec.isLoading) {
                Future.microtask(() => rec.loadRecords(auth.token!));
              }
            } else {
              Future.microtask(rec.clear);
            }
            return rec;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, CardController>(
          create: (_) => CardController(),
          update: (_, auth, card) {
            final cc = card ?? CardController();
            if (auth.isAuthenticated) {
              if (!cc.loaded && !cc.loading) Future.microtask(cc.load);
            } else {
              Future.microtask(cc.clear);
            }
            return cc;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, ChatController>(
          create: (_) => ChatController(),
          update: (_, auth, chat) {
            final ch = chat ?? ChatController();
            if (auth.isAuthenticated) {
              if (!ch.loaded) Future.microtask(() => ch.loadConversations(auth.token!));
            } else {
              Future.microtask(ch.clear);
            }
            return ch;
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
      ],
      child: child,
    );
  }
}
