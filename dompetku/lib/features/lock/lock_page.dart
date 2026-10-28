import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/app_lock_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pin_pad.dart';
import 'app_reset_dialog.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  static const _maxLength = 6;

  String _pin = '';
  String? _error;
  Timer? _ticker;
  bool _biometricStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBiometric());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _startBiometric() async {
    if (_biometricStarted || !mounted) return;
    final state = ref.read(appLockControllerProvider);
    if (!state.canUseBiometric) return;
    _biometricStarted = true;
    _ensureTicker();
    final ok = await ref.read(appLockControllerProvider.notifier).unlockWithBiometric();
    if (ok || !mounted) return;
    setState(() => _error = 'Sidik jari tidak dikenali. Gunakan PIN.');
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = ref
          .read(appLockControllerProvider)
          .cooldownRemainingAt(DateTime.now());
      if (remaining == Duration.zero) {
        _ticker?.cancel();
        _ticker = null;
      }
      setState(() {});
    });
  }

  void _onDigit(int digit) {
    if (_pin.length >= _maxLength) return;
    setState(() {
      _pin += '$digit';
      _error = null;
    });
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_pin.length < 4) {
      setState(() => _error = 'PIN minimal 4 angka.');
      return;
    }
    _error = null;
    try {
      await ref.read(appLockControllerProvider.notifier).unlockWithPin(_pin);
      if (mounted) setState(() => _pin = '');
    } on AppLockException catch (error) {
      if (!mounted) return;
      _ensureTicker();
      setState(() {
        _pin = '';
        _error = error.message;
      });
    }
  }

  Future<void> _showReset() async {
    await showAppResetDialog(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = ref.watch(appLockControllerProvider);
    final remaining = state.cooldownRemainingAt(DateTime.now());
    final coolingDown = remaining > Duration.zero;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              children: [
                Image.asset(
                  isDark
                      ? 'assets/branding/lockup_horizontal_dark.png'
                      : 'assets/branding/lockup_horizontal_light.png',
                  height: 40,
                ),
                const SizedBox(height: 30),
                Icon(Icons.lock_rounded, size: 30, color: p.emerald),
                const SizedBox(height: 10),
                Text(
                  'DompetKu terkunci',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: p.slate,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masukkan PIN untuk melihat keuangan Anda',
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
                const SizedBox(height: 26),
                PinDots(filled: _pin.length, error: _error != null),
                const SizedBox(height: 18),
                SizedBox(
                  height: 38,
                  child: coolingDown
                      ? Text(
                          'Tunggu ${remaining.inSeconds} detik sebelum mencoba lagi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.warning,
                          ),
                        )
                      : _error == null
                      ? null
                      : Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.expense,
                          ),
                        ),
                ),
                if (state.canUseBiometric) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _startBiometric,
                    icon: const Icon(Icons.fingerprint_rounded, size: 26),
                    label: const Text('Sidik jari'),
                    style: TextButton.styleFrom(
                      foregroundColor: p.emerald,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                PinPad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  onSubmit: _submit,
                  submitEnabled: _pin.length >= 4 && !coolingDown && !state.busy,
                  submitLabel: state.busy ? '...' : 'Buka',
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: _showReset,
                  child: Text(
                    'Lupa PIN? Reset aplikasi',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
