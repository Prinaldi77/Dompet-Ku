import 'package:dompetku/app.dart';
import 'package:dompetku/core/database/app_database.dart';
import 'package:dompetku/core/providers/app_providers.dart';
import 'package:dompetku/core/security/app_lock_controller.dart';
import 'package:dompetku/core/security/app_lock_store.dart';
import 'package:dompetku/core/theme/theme_mode.dart';
import 'package:dompetku/features/dashboard/dashboard_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _fakeDerive(String pin, String salt) async => 'fake:2468';

const _enabledConfig = LockConfig(
  enabled: true,
  biometricEnabled: false,
  pinSalt: 'c2FsdA==',
  pinHash: 'fake:2468',
);

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'app_lock_enabled': true,
      'app_lock_pin_salt': 'c2FsdA==',
      'app_lock_pin_hash': 'fake:2468',
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  ProviderContainer buildContainer({required LockConfig config}) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        themeModeProvider.overrideWith((ref) => ThemeMode.light),
        appLockControllerProvider.overrideWith(
          () => AppLockController(initialConfig: config, pinDeriver: _fakeDerive),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DompetkuApp(showOnboarding: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('kunci aktif saat cold start → dashboard tidak dirender', (
    tester,
  ) async {
    await pump(tester, buildContainer(config: _enabledConfig));

    expect(find.text('DompetKu terkunci'), findsOneWidget);
    expect(find.byType(DashboardPage), findsNothing);
  });

  testWidgets('setelah PIN benar, pengguna diarahkan ke dashboard', (
    tester,
  ) async {
    final container = buildContainer(config: _enabledConfig);
    await pump(tester, container);

    await container
        .read(appLockControllerProvider.notifier)
        .unlockWithPin('2468');
    await tester.pumpAndSettle();

    expect(find.text('DompetKu terkunci'), findsNothing);
    expect(find.byType(DashboardPage), findsOneWidget);
  });

  testWidgets('kunci nonaktif → langsung dashboard tanpa layar kunci', (
    tester,
  ) async {
    await pump(
      tester,
      buildContainer(
        config: const LockConfig(enabled: false, biometricEnabled: false),
      ),
    );

    expect(find.text('DompetKu terkunci'), findsNothing);
    expect(find.byType(DashboardPage), findsOneWidget);
  });
}
