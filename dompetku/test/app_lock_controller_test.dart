import 'package:dompetku/core/security/app_lock_controller.dart';
import 'package:dompetku/core/security/app_lock_store.dart';
import 'package:dompetku/core/security/biometric_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deriver cepat untuk test: hash hanyalah prefiks tetap + PIN.
Future<String> _fakeDerive(String pin, String salt) async => 'fake:$pin';

/// Gate tiruan yang statusnya bisa diubah test untuk mensimulasikan
/// pengguna yang mendaftarkan sidik jari saat aplikasi berjalan.
class _StubGate extends BiometricGate {
  _StubGate(this.statusValue);

  BiometricStatus statusValue;
  int statusCalls = 0;

  @override
  Future<BiometricStatus> status() async {
    statusCalls++;
    return statusValue;
  }

  @override
  Future<BiometricResult> authenticate({String reason = 'Buka DompetKu'}) async =>
      const BiometricResult(false);
}

ProviderContainer createLockContainer({
  LockConfig? initialConfig,
  DateTime Function()? clock,
  BiometricGate? gate,
}) {
  final container = ProviderContainer(
    overrides: [
      appLockControllerProvider.overrideWith(
        () => AppLockController(
          initialConfig: initialConfig,
          pinDeriver: _fakeDerive,
          clock: clock,
          gate: gate,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

LockConfig enabledConfig() =>
    const LockConfig(
      enabled: true,
      biometricEnabled: false,
      pinSalt: 'c2FsdA==',
      pinHash: 'fake:2468',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppLockController · status awal', () {
    test('kunci belum aktif → tidak ada layar kunci', () {
      final container = createLockContainer();
      expect(container.read(appLockControllerProvider).stage, LockStage.disabled);
    });

    test('kunci aktif saat cold start → langsung terkunci', () {
      final container = createLockContainer(initialConfig: enabledConfig());
      expect(container.read(appLockControllerProvider).isLocked, isTrue);
    });

    test('sidik jari dianggap tidak tersedia bila perangkat belum mendukung', () {
      final container = createLockContainer(initialConfig: enabledConfig());
      final state = container.read(appLockControllerProvider);
      expect(state.canUseBiometric, isFalse);
    });

    test('kunci tetap berstatus aktif setelah terbuka', () async {
      SharedPreferences.setMockInitialValues({
        'app_lock_enabled': true,
        'app_lock_pin_salt': 'c2FsdA==',
        'app_lock_pin_hash': 'fake:2468',
      });
      final container = createLockContainer(initialConfig: enabledConfig());
      await container
          .read(appLockControllerProvider.notifier)
          .unlockWithPin('2468');

      final state = container.read(appLockControllerProvider);
      expect(state.enabled, isTrue);
      expect(state.isLocked, isFalse);
    });
  });

  group('AppLockController · membuka kunci', () {
    test('PIN benar melepas kunci', () async {
      SharedPreferences.setMockInitialValues({
        'app_lock_enabled': true,
        'app_lock_pin_salt': 'c2FsdA==',
        'app_lock_pin_hash': 'fake:2468',
      });
      final container = createLockContainer(initialConfig: enabledConfig());
      final notifier = container.read(appLockControllerProvider.notifier);

      await notifier.unlockWithPin('2468');

      final state = container.read(appLockControllerProvider);
      expect(state.stage, LockStage.unlocked);
      expect(state.failedAttempts, 0);
    });

    test('PIN salah mengurangi jatah percobaan', () async {
      SharedPreferences.setMockInitialValues({
        'app_lock_enabled': true,
        'app_lock_pin_salt': 'c2FsdA==',
        'app_lock_pin_hash': 'fake:2468',
      });
      final container = createLockContainer(initialConfig: enabledConfig());
      final notifier = container.read(appLockControllerProvider.notifier);

      Object? error;
      try {
        await notifier.unlockWithPin('1357');
      } on AppLockException catch (e) {
        error = e;
      }

      expect(error, isA<AppLockException>());
      expect((error as AppLockException).message, contains('Sisa percobaan: 4'));
      expect(container.read(appLockControllerProvider).isLocked, isTrue);
    });

    test('lima PIN salah memicu cooldown 60 detik', () async {
      SharedPreferences.setMockInitialValues({
        'app_lock_enabled': true,
        'app_lock_pin_salt': 'c2FsdA==',
        'app_lock_pin_hash': 'fake:2468',
      });
      var now = DateTime(2026, 10, 28, 10);
      final container = createLockContainer(
        initialConfig: enabledConfig(),
        clock: () => now,
      );
      final notifier = container.read(appLockControllerProvider.notifier);

      AppLockException? lastError;
      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(seconds: 2));
        try {
          await notifier.unlockWithPin('0000');
        } on AppLockException catch (e) {
          lastError = e;
        }
      }

      expect(lastError?.message, contains('5 kali'));
      final state = container.read(appLockControllerProvider);
      expect(state.cooldownRemainingAt(now), appLockCooldown);

      // PIN benar tetap ditolak selama cooldown berjalan.
      now = now.add(const Duration(seconds: 30));
      expect(
        () => notifier.unlockWithPin('2468'),
        throwsA(isA<AppLockException>()),
      );

      // Setelah cooldown lewat, PIN benar membuka kunci.
      now = now.add(const Duration(seconds: 31));
      await notifier.unlockWithPin('2468');
      expect(container.read(appLockControllerProvider).stage, LockStage.unlocked);
    });
  });

  group('AppLockController · auto-lock', () {
    Future<AppLockController> unlockedNotifier(
      DateTime Function() clock,
    ) async {
      SharedPreferences.setMockInitialValues({
        'app_lock_enabled': true,
        'app_lock_pin_salt': 'c2FsdA==',
        'app_lock_pin_hash': 'fake:2468',
      });
      final container = createLockContainer(
        initialConfig: enabledConfig(),
        clock: clock,
      );
      final notifier = container.read(appLockControllerProvider.notifier);
      await notifier.unlockWithPin('2468');
      expect(notifier.state.isLocked, isFalse);
      return notifier;
    }

    test('resume setelah lebih dari 30 detik mengunci kembali', () async {
      var now = DateTime(2026, 10, 28, 10);
      final notifier = await unlockedNotifier(() => now);

      notifier.notifyBackgrounded();
      now = now.add(const Duration(seconds: 31));
      notifier.notifyResumed();

      expect(notifier.state.isLocked, isTrue);
    });

    test('resume cepat tidak mengunci kembali', () async {
      var now = DateTime(2026, 10, 28, 10);
      final notifier = await unlockedNotifier(() => now);

      notifier.notifyBackgrounded();
      now = now.add(const Duration(seconds: 10));
      notifier.notifyResumed();

      expect(notifier.state.isLocked, isFalse);
    });

    test('hidden susulan sebelum resumed tidak menimpa waktu latar', () async {
      var now = DateTime(2026, 10, 28, 10);
      final notifier = await unlockedNotifier(() => now);

      // Urutan nyata di Android: hidden + paused saat pergi, lalu hidden
      // lagi sesaat sebelum resumed.
      notifier.notifyBackgrounded();
      now = now.add(const Duration(seconds: 45));
      notifier.notifyBackgrounded();
      notifier.notifyResumed();

      expect(notifier.state.isLocked, isTrue);
    });

    test('resume me-refresh ketersediaan sidik jari', () async {
      final gate = _StubGate(BiometricStatus.notEnrolled);
      final container = createLockContainer(
        initialConfig: enabledConfig(),
        gate: gate,
      );
      expect(container.read(appLockControllerProvider).isLocked, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(appLockControllerProvider).biometricStatus,
        BiometricStatus.notEnrolled,
      );

      // Pengguna mendaftarkan sidik jari di pengaturan sistem, lalu kembali.
      gate.statusValue = BiometricStatus.available;
      final callsBefore = gate.statusCalls;
      container.read(appLockControllerProvider.notifier).notifyResumed();
      await Future<void>.delayed(Duration.zero);

      expect(gate.statusCalls, greaterThan(callsBefore));
      expect(container.read(appLockControllerProvider).biometricStatus,
          BiometricStatus.available);
    });
  });

  group('AppLockController · aktivasi & nonaktif', () {
    test('enable menyimpan hash PIN dan membuka kunci', () async {
      final container = createLockContainer();
      await container
          .read(appLockControllerProvider.notifier)
          .enable(pin: '5183', biometricEnabled: false);

      final stored = await AppLockStore().read();
      expect(stored.enabled, isTrue);
      expect(stored.hasPin, isTrue);
      expect(stored.pinSalt, isNotEmpty);
      expect(container.read(appLockControllerProvider).stage, LockStage.unlocked);
    });

    test('enable menolak PIN lemah', () async {
      final container = createLockContainer();
      expect(
        () => container
            .read(appLockControllerProvider.notifier)
            .enable(pin: '1234', biometricEnabled: false),
        throwsA(isA<AppLockException>()),
      );
      final stored = await AppLockStore().read();
      expect(stored.enabled, isFalse);
    });

    test('changePin menolak PIN lama yang salah', () async {
      SharedPreferences.setMockInitialValues({
        'app_lock_enabled': true,
        'app_lock_pin_salt': 'c2FsdA==',
        'app_lock_pin_hash': 'fake:2468',
      });
      final container = createLockContainer(initialConfig: enabledConfig());

      expect(
        () => container
            .read(appLockControllerProvider.notifier)
            .changePin(oldPin: '9999', newPin: '7029'),
        throwsA(isA<AppLockException>()),
      );

      await container
          .read(appLockControllerProvider.notifier)
          .changePin(oldPin: '2468', newPin: '7029');
      final stored = await AppLockStore().read();
      expect(stored.pinHash, 'fake:7029');
    });

    test('disable memerlukan PIN dan membersihkan konfigurasi', () async {
      SharedPreferences.setMockInitialValues({
        'app_lock_enabled': true,
        'app_lock_pin_salt': 'c2FsdA==',
        'app_lock_pin_hash': 'fake:2468',
      });
      final container = createLockContainer(initialConfig: enabledConfig());
      final notifier = container.read(appLockControllerProvider.notifier);

      expect(
        () => notifier.disable(pin: '1111'),
        throwsA(isA<AppLockException>()),
      );

      await notifier.disable(pin: '2468');
      expect(container.read(appLockControllerProvider).stage, LockStage.disabled);
      final stored = await AppLockStore().read();
      expect(stored.enabled, isFalse);
      expect(stored.hasPin, isFalse);
    });
  });
}
