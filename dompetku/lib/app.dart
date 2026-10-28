import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_info.dart';
import 'core/router/app_router.dart';
import 'core/security/app_lock_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';

class DompetkuApp extends ConsumerStatefulWidget {
  const DompetkuApp({super.key, required this.showOnboarding});

  final bool showOnboarding;

  @override
  ConsumerState<DompetkuApp> createState() => _DompetkuAppState();
}

class _DompetkuAppState extends ConsumerState<DompetkuApp>
    with WidgetsBindingObserver {
  final _lockRefresh = ValueNotifier<int>(0);

  late final GoRouter _router = createAppRouter(
    showOnboarding: widget.showOnboarding,
    lockRefresh: _lockRefresh,
    isLocked: () => ref.read(appLockControllerProvider).isLocked,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockRefresh.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        controller.notifyBackgrounded();
      case AppLifecycleState.resumed:
        controller.notifyResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appLockControllerProvider, (previous, next) {
      final wasLocked = previous?.isLocked ?? false;
      if (wasLocked != next.isLocked) _lockRefresh.value++;
    });

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
