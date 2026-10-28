import 'package:dompetku/core/security/app_lock_controller.dart';
import 'package:dompetku/core/security/app_lock_store.dart';
import 'package:dompetku/core/security/biometric_gate.dart';
import 'package:dompetku/core/theme/app_theme.dart';
import 'package:dompetku/features/lock/lock_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubGate extends BiometricGate {
  _StubGate(this._status);

  final BiometricStatus _status;

  @override
  Future<BiometricStatus> status() async => _status;

  @override
  Future<BiometricResult> authenticate({String reason = 'Buka DompetKu'}) async =>
      const BiometricResult(true);
}

Future<String> _fakeDerive(String pin, String salt) async => 'fake:$pin';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pumpSetupPage(
    WidgetTester tester, {
    required BiometricStatus biometricStatus,
    String mode = 'create',
  }) async {
    final container = ProviderContainer(
      overrides: [
        appLockControllerProvider.overrideWith(
          () => AppLockController(
            initialConfig: LockConfig(enabled: false, biometricEnabled: false),
            pinDeriver: _fakeDerive,
            gate: _StubGate(biometricStatus),
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
          home: LockSetupPage(mode: mode),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('sidik jari tersedia → pilihan tampil dan sudah tercentang', (
    tester,
  ) async {
    await pumpSetupPage(tester, biometricStatus: BiometricStatus.available);

    expect(find.text('Gunakan sidik jari'), findsOneWidget);
    // Status sensor tiba setelah build pertama, jadi defaultnya harus ikut
    // tersentuh tanpa menekan checkbox.
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
  });

  testWidgets('sidik jari tidak tersedia → pilihan disembunyikan', (
    tester,
  ) async {
    await pumpSetupPage(tester, biometricStatus: BiometricStatus.notEnrolled);

    expect(find.text('Gunakan sidik jari'), findsNothing);
  });

  testWidgets('pengguna bisa menghapus centang sidik jari', (tester) async {
    await pumpSetupPage(tester, biometricStatus: BiometricStatus.available);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
  });

  testWidgets('mode ganti PIN tidak menampilkan pilihan sidik jari', (
    tester,
  ) async {
    await pumpSetupPage(
      tester,
      biometricStatus: BiometricStatus.available,
      mode: 'change',
    );

    expect(find.text('Gunakan sidik jari'), findsNothing);
    expect(find.text('Ganti PIN'), findsOneWidget);
  });
}
