import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/app_lock_controller.dart';
import '../../core/security/biometric_gate.dart';
import '../../core/security/pin_hash.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pin_pad.dart';

/// Halaman bertahap untuk mengaktifkan, mengubah, atau mematikan kunci PIN.
class LockSetupPage extends ConsumerStatefulWidget {
  const LockSetupPage({super.key, required this.mode});

  /// create | change | disable
  final String mode;

  @override
  ConsumerState<LockSetupPage> createState() => _LockSetupPageState();
}

class _LockSetupPageState extends ConsumerState<LockSetupPage> {
  String _pin = '';
  String? _firstPin;
  String? _error;
  bool _busy = false;
  bool _biometricTouched = false;
  bool _biometric = false;

  bool get _biometricAvailable =>
      ref.read(appLockControllerProvider).biometricStatus ==
      BiometricStatus.available;

  /// Default: ikut ketersediaan sensor, kecuali pengguna sudah mengubahnya.
  bool get _biometricChoice =>
      _biometricTouched ? _biometric : _biometricAvailable;

  String get _title => switch (widget.mode) {
    'change' => 'Ganti PIN',
    'disable' => 'Matikan Kunci Aplikasi',
    _ => 'Aktifkan Kunci Aplikasi',
  };

  String get _prompt {
    if (widget.mode == 'disable') return 'Masukkan PIN Anda saat ini';
    if (widget.mode == 'change') {
      return _firstPin == null
          ? 'Masukkan PIN Anda saat ini'
          : 'Masukkan PIN baru';
    }
    return _firstPin == null ? 'Buat PIN 4–6 angka' : 'Ulangi PIN Anda';
  }

  bool get _needOldPinStep => widget.mode == 'change' && _firstPin == null;

  void _onDigit(int digit) {
    if (_pin.length >= pinLengthMax) return;
    setState(() {
      _pin += '$digit';
      _error = null;
    });
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(doneMessage)));
      context.pop();
    } on AppLockException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin = '';
        _error = error.message;
      });
    }
  }

  Future<void> _submit() async {
    if (_pin.length < pinLengthMin) {
      setState(() => _error = 'PIN minimal $pinLengthMin angka.');
      return;
    }
    final controller = ref.read(appLockControllerProvider.notifier);

    if (widget.mode == 'disable') {
      await _run(() => controller.disable(pin: _pin), 'Kunci aplikasi dimatikan.');
      return;
    }

    if (_needOldPinStep) {
      setState(() => _busy = true);
      try {
        await controller.verifyPin(_pin);
        if (!mounted) return;
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _busy = false;
        });
      } on AppLockException catch (error) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _pin = '';
          _error = error.message;
        });
      }
      return;
    }

    if (_firstPin == null) {
      final invalid = pinValidationError(_pin);
      if (invalid.isNotEmpty) {
        setState(() => _error = invalid);
        return;
      }
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
      return;
    }

    if (_firstPin != _pin) {
      setState(() {
        _firstPin = null;
        _pin = '';
        _error = 'PIN tidak sama. Silakan mulai lagi.';
      });
      return;
    }

    if (widget.mode == 'change') {
      await _run(
        () => controller.changePin(oldPin: _firstPin!, newPin: _pin),
        'PIN berhasil diganti.',
      );
      return;
    }
    await _run(
      () => controller.enable(
        pin: _pin,
        biometricEnabled: _biometricChoice,
      ),
      _biometricChoice
          ? 'Kunci aplikasi aktif. Sidik jari bisa dipakai untuk membuka.'
          : 'Kunci aplikasi aktif.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Dipantau agar default centang ikut saat status sensor sudah terbaca.
    ref.watch(appLockControllerProvider);
    final showBiometricChoice = widget.mode == 'create' && _biometricAvailable;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Text(
                _prompt,
                style: TextStyle(fontSize: 13.5, color: p.muted),
              ),
              const SizedBox(height: 18),
              PinDots(filled: _pin.length, error: _error != null),
              const SizedBox(height: 14),
              SizedBox(
                height: 20,
                child: _error == null
                    ? null
                    : Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.expense,
                        ),
                      ),
              ),
              if (showBiometricChoice)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: CheckboxListTile(
                    value: _biometricChoice,
                    onChanged: (value) => setState(() {
                      _biometricTouched = true;
                      _biometric = value ?? false;
                    }),
                    title: const Text(
                      'Gunakan sidik jari',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Sidik jari membuka lebih cepat; PIN tetap jadi cadangan.',
                      style: TextStyle(fontSize: 11.5, color: p.muted),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const SizedBox(height: 12),
              PinPad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onSubmit: _submit,
                submitEnabled: _pin.length >= pinLengthMin && !_busy,
                submitLabel: _busy
                    ? '...'
                    : (widget.mode == 'disable' || _needOldPinStep
                          ? 'Lanjut'
                          : (_firstPin == null ? 'Lanjut' : 'Simpan')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
