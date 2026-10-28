import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricStatus { available, notEnrolled, notSupported, notPermitted }

class BiometricResult {
  const BiometricResult(this.success, {this.error});

  final bool success;
  final String? error;
}

/// Pembungkus `local_auth` untuk membuka kunci dengan sidik jari/Face ID.
class BiometricGate {
  BiometricGate({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<BiometricStatus> status() async {
    try {
      if (!await _auth.isDeviceSupported()) return BiometricStatus.notPermitted;
      final types = await _auth.getAvailableBiometrics();
      return types.isEmpty ? BiometricStatus.notEnrolled : BiometricStatus.available;
    } on PlatformException {
      return BiometricStatus.notSupported;
    } catch (_) {
      return BiometricStatus.notSupported;
    }
  }

  /// [biometricOnly] aktif: kunci layar perangkat tidak dipakai sebagai
  /// fallback, karena aplikasi ini punya PIN sendiri. Teks sistem BiometricPrompt
  /// mengikuti locale perangkat.
  Future<BiometricResult> authenticate({String reason = 'Buka DompetKu'}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return BiometricResult(ok);
    } on PlatformException catch (error) {
      return BiometricResult(false, error: error.message ?? error.code);
    }
  }
}
