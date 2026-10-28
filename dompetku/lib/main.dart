import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/backup/backup_reminder.dart';
import 'core/onboarding/onboarding_prefs.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/app_lock_store.dart';
import 'core/theme/theme_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final themeMode = await loadThemeMode();
  final onboardingDone = await loadOnboardingDone();
  final lastBackupAt = await loadLastBackupAt();
  final firstOpenAt = await loadOrCreateFirstOpenAt();
  final lockStore = AppLockStore();
  final lockConfig = await lockStore.read();
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => themeMode),
        lastBackupAtProvider.overrideWith((ref) => lastBackupAt),
        firstOpenAtProvider.overrideWith((ref) => firstOpenAt),
        appLockStoreProvider.overrideWithValue(lockStore),
        appLockControllerProvider.overrideWith(
          () => AppLockController(initialConfig: lockConfig),
        ),
      ],
      child: DompetkuApp(showOnboarding: !onboardingDone),
    ),
  );
}
