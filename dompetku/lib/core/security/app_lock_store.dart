import 'package:shared_preferences/shared_preferences.dart';

class LockConfig {
  const LockConfig({
    required this.enabled,
    required this.biometricEnabled,
    this.pinSalt,
    this.pinHash,
  });

  final bool enabled;
  final bool biometricEnabled;
  final String? pinSalt;
  final String? pinHash;

  bool get hasPin => (pinSalt?.isNotEmpty ?? false) && (pinHash?.isNotEmpty ?? false);
}

/// Menyimpan konfigurasi kunci aplikasi di SharedPreferences.
///
/// Hanya turunan PBKDF2 dari PIN yang disimpan, bukan PIN aslinya.
class AppLockStore {
  static const _enabledKey = 'app_lock_enabled';
  static const _biometricKey = 'app_lock_biometric';
  static const _saltKey = 'app_lock_pin_salt';
  static const _hashKey = 'app_lock_pin_hash';

  Future<LockConfig> read() async {
    final prefs = await SharedPreferences.getInstance();
    return LockConfig(
      enabled: prefs.getBool(_enabledKey) ?? false,
      biometricEnabled: prefs.getBool(_biometricKey) ?? false,
      pinSalt: prefs.getString(_saltKey),
      pinHash: prefs.getString(_hashKey),
    );
  }

  Future<void> save({
    required bool enabled,
    required bool biometricEnabled,
    String? pinSalt,
    String? pinHash,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setBool(_biometricKey, biometricEnabled);
    if (pinSalt != null) await prefs.setString(_saltKey, pinSalt);
    if (pinHash != null) await prefs.setString(_hashKey, pinHash);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
    await prefs.remove(_biometricKey);
    await prefs.remove(_saltKey);
    await prefs.remove(_hashKey);
  }
}
