import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_store.dart';
import 'biometric_gate.dart';
import 'pin_hash.dart';

enum LockStage { disabled, unlocked, locked }

const Duration appLockTimeout = Duration(seconds: 30);
const int appLockMaxAttempts = 5;
const Duration appLockCooldown = Duration(seconds: 60);

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.stage,
    this.biometricEnabled = false,
    this.biometricStatus = BiometricStatus.notSupported,
    this.failedAttempts = 0,
    this.cooldownUntil,
    this.busy = false,
  });

  /// Kunci dipasang di pengaturan, terlepas dari layar sedang terbuka atau terkunci.
  final bool enabled;
  final LockStage stage;
  final bool biometricEnabled;
  final BiometricStatus biometricStatus;
  final int failedAttempts;
  final DateTime? cooldownUntil;
  final bool busy;

  bool get isLocked => enabled && stage == LockStage.locked;
  bool get canUseBiometric =>
      biometricEnabled && biometricStatus == BiometricStatus.available;

  Duration cooldownRemainingAt(DateTime now) {
    final until = cooldownUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  AppLockState copyWith({
    bool? enabled,
    LockStage? stage,
    bool? biometricEnabled,
    BiometricStatus? biometricStatus,
    int? failedAttempts,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
    bool? busy,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      stage: stage ?? this.stage,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricStatus: biometricStatus ?? this.biometricStatus,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      cooldownUntil: clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
      busy: busy ?? this.busy,
    );
  }
}

typedef PinDeriver = Future<String> Function(String pin, String salt);

Future<String> _deriveInIsolate(String pin, String salt) =>
    Isolate.run(() => hashPin(pin, salt));

final appLockStoreProvider = Provider<AppLockStore>((_) => AppLockStore());

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

class AppLockController extends Notifier<AppLockState> {
  AppLockController({
    LockConfig? initialConfig,
    PinDeriver? pinDeriver,
    DateTime Function()? clock,
    BiometricGate? gate,
  }) : _initialConfig = initialConfig,
       _derive = pinDeriver ?? _deriveInIsolate,
       _clock = clock ?? DateTime.now,
       _gate = gate ?? BiometricGate();

  final LockConfig? _initialConfig;
  final PinDeriver _derive;
  final DateTime Function() _clock;

  AppLockStore get _store => ref.read(appLockStoreProvider);
  final BiometricGate _gate;
  DateTime? _backgroundedAt;
  bool _disposed = false;

  @override
  AppLockState build() {
    ref.onDispose(() => _disposed = true);
    final config = _initialConfig ?? LockConfig(enabled: false, biometricEnabled: false);
    _refreshBiometrics();
    return AppLockState(
      enabled: config.enabled,
      stage: config.enabled ? LockStage.locked : LockStage.disabled,
      biometricEnabled: config.biometricEnabled,
    );
  }

  Future<void> _refreshBiometrics() async {
    final status = await _gate.status();
    if (_disposed) return;
    state = state.copyWith(biometricStatus: status);
  }

  Future<void> unlockWithPin(String pin) async {
    final now = _clock();
    if (state.cooldownRemainingAt(now) > Duration.zero) {
      throw const AppLockException(
        'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
      );
    }
    final config = await _store.read();
    if (!config.hasPin) {
      throw const AppLockException('PIN belum disetel di pengaturan.');
    }

    state = state.copyWith(busy: true);
    try {
      final hash = await _derive(pin, config.pinSalt!);
      if (hash == config.pinHash) {
        state = state.copyWith(
          stage: LockStage.unlocked,
          failedAttempts: 0,
          clearCooldown: true,
          busy: false,
        );
        return;
      }
      _registerFailure(now);
    } catch (error) {
      state = state.copyWith(busy: false);
      rethrow;
    }
  }

  void _registerFailure(DateTime now) {
    final attempts = state.failedAttempts + 1;
    if (attempts >= appLockMaxAttempts) {
      state = state.copyWith(
        failedAttempts: 0,
        cooldownUntil: now.add(appLockCooldown),
        busy: false,
      );
      throw const AppLockException(
        'PIN salah 5 kali. Coba lagi setelah 60 detik.',
      );
    }
    state = state.copyWith(failedAttempts: attempts, busy: false);
    throw AppLockException('PIN salah. Sisa percobaan: ${appLockMaxAttempts - attempts}.');
  }

  Future<bool> unlockWithBiometric() async {
    final result = await _gate.authenticate();
    if (!result.success) return false;
    state = state.copyWith(
      stage: LockStage.unlocked,
      failedAttempts: 0,
      clearCooldown: true,
    );
    return true;
  }

  void lock() {
    if (!state.enabled) return;
    state = state.copyWith(
      stage: LockStage.locked,
      failedAttempts: 0,
      clearCooldown: true,
    );
  }

  void notifyBackgrounded() => _backgroundedAt = _clock();

  void notifyResumed() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;
    if (_clock().difference(since) > appLockTimeout) lock();
  }

  /// Mengaktifkan kunci aplikasi dengan PIN baru.
  Future<void> enable({
    required String pin,
    required bool biometricEnabled,
  }) async {
    final invalid = pinValidationError(pin);
    if (invalid.isNotEmpty) throw AppLockException(invalid);
    if (biometricEnabled &&
        state.biometricStatus != BiometricStatus.available) {
      throw const AppLockException(
        'Belum ada sidik jari terdaftar di perangkat ini.',
      );
    }

    final salt = generatePinSalt();
    final hash = await _derive(pin, salt);
    await _store.save(
      enabled: true,
      biometricEnabled: biometricEnabled,
      pinSalt: salt,
      pinHash: hash,
    );
    state = state.copyWith(
      enabled: true,
      stage: LockStage.unlocked,
      biometricEnabled: biometricEnabled,
      failedAttempts: 0,
      clearCooldown: true,
    );
  }

  Future<void> changePin({required String oldPin, required String newPin}) async {
    await verifyPin(oldPin);
    final invalid = pinValidationError(newPin);
    if (invalid.isNotEmpty) throw AppLockException(invalid);

    final salt = generatePinSalt();
    final hash = await _derive(newPin, salt);
    final config = await _store.read();
    await _store.save(
      enabled: true,
      biometricEnabled: config.biometricEnabled,
      pinSalt: salt,
      pinHash: hash,
    );
  }

  Future<void> verifyPin(String pin) async {
    final config = await _store.read();
    if (!config.hasPin) throw const AppLockException('PIN belum disetel.');
    final hash = await _derive(pin, config.pinSalt!);
    if (hash != config.pinHash) {
      throw const AppLockException('PIN tidak cocok.');
    }
  }

  Future<void> setBiometric(bool enabled) async {
    if (enabled) {
      if (state.biometricStatus != BiometricStatus.available) {
        throw const AppLockException(
          'Sidik jari belum tersedia atau belum terdaftar di perangkat ini.',
        );
      }
      final result = await _gate.authenticate(
        reason: 'Daftarkan sidik jari untuk DompetKu',
      );
      if (!result.success) {
        throw const AppLockException('Autentikasi sidik jari dibatalkan.');
      }
    }
    await _store.save(enabled: true, biometricEnabled: enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> disable({required String pin}) async {
    await verifyPin(pin);
    await _store.clear();
    state = const AppLockState(enabled: false, stage: LockStage.disabled);
    _refreshBiometrics();
  }

  /// Dipakai saat reset data: menghapus konfigurasi tanpa verifikasi PIN.
  Future<void> clearConfig() async {
    await _store.clear();
    state = const AppLockState(enabled: false, stage: LockStage.disabled);
  }
}

class AppLockException implements Exception {
  const AppLockException(this.message);

  final String message;

  @override
  String toString() => message;
}
