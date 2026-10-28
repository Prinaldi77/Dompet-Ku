import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_info.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';

class DompetkuApp extends ConsumerStatefulWidget {
  const DompetkuApp({super.key, required this.showOnboarding});

  final bool showOnboarding;

  @override
  ConsumerState<DompetkuApp> createState() => _DompetkuAppState();
}

class _DompetkuAppState extends ConsumerState<DompetkuApp> {
  late final GoRouter _router = createAppRouter(
    showOnboarding: widget.showOnboarding,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
