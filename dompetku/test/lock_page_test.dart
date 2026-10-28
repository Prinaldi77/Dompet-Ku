import 'package:dompetku/core/security/app_lock_controller.dart';
import 'package:dompetku/core/security/app_lock_store.dart';
import 'package:dompetku/core/theme/app_theme.dart';
import 'package:dompetku/core/widgets/pin_pad.dart';
import 'package:dompetku/features/lock/lock_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _fakeDerive(String pin, String salt) async => 'fake:$pin';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
    'app_lock_enabled': true,
    'app_lock_pin_salt': 'c2FsdA==',
    'app_lock_pin_hash': 'fake:2468',
  }));

  Future<ProviderContainer> pumpLockPage(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        appLockControllerProvider.overrideWith(
          () => AppLockController(
            initialConfig: const LockConfig(
              enabled: true,
              biometricEnabled: false,
              pinSalt: 'c2FsdA==',
              pinHash: 'fake:2468',
            ),
            pinDeriver: _fakeDerive,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const LockPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
  }

  testWidgets('layar kunci menampilkan judul, keypad, dan tautan reset', (
    tester,
  ) async {
    await pumpLockPage(tester);

    expect(find.text('DompetKu terkunci'), findsOneWidget);
    expect(find.text('Buka'), findsOneWidget);
    expect(find.text('Lupa PIN? Reset aplikasi'), findsOneWidget);
    // Perangkat test tidak punya sidik jari, jadi tombolnya disembunyikan.
    expect(find.text('Sidik jari'), findsNothing);
  });

  testWidgets('PIN benar melepas kunci', (tester) async {
    final container = await pumpLockPage(tester);
    expect(container.read(appLockControllerProvider).isLocked, isTrue);

    await typePin(tester, '2468');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(container.read(appLockControllerProvider).stage, LockStage.unlocked);
  });

  testWidgets('PIN salah menampilkan sisa percobaan dan tetap terkunci', (
    tester,
  ) async {
    final container = await pumpLockPage(tester);

    await typePin(tester, '1357');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sisa percobaan: 4'), findsOneWidget);
    expect(container.read(appLockControllerProvider).isLocked, isTrue);
  });

  testWidgets('PIN kurang dari 4 angka tidak bisa dikirim', (tester) async {
    final container = await pumpLockPage(tester);

    await typePin(tester, '246');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(container.read(appLockControllerProvider).isLocked, isTrue);
    expect(find.textContaining('Sisa percobaan'), findsNothing);
  });

  testWidgets('tombol hapus menghapus digit terakhir', (tester) async {
    await pumpLockPage(tester);

    await typePin(tester, '2468');
    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 4);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    expect(tester.widget<PinDots>(find.byType(PinDots)).filled, 3);
  });
}
