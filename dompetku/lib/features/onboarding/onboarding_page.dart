import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ledger/ledger_service.dart';
import '../../core/onboarding/onboarding_prefs.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  final _amountController = TextEditingController();
  int _index = 0;
  bool _showBalanceStep = false;
  bool _checking = false;
  bool _saving = false;
  String? _amountError;

  static const _slides = [
    _SlideData(
      icon: Icons.receipt_long_rounded,
      title: 'Catat transaksi tanpa ribet',
      body:
          'Pemasukan dan pengeluaran tersimpan rapi per kategori, lengkap dengan ringkasan dan grafik tiap bulan.',
    ),
    _SlideData(
      icon: Icons.savings_rounded,
      title: 'Wujudkan target tabungan',
      body:
          'Buat target, catat setoran, dan pantau progresnya. Saldo utama otomatis menyesuaikan.',
    ),
    _SlideData(
      icon: Icons.handshake_rounded,
      title: 'Utang & piutang terkendali',
      body:
          'Catat cicilan, pantau jatuh tempo, dan jaga catatan tetap akurat sampai lunas.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    if (!mounted) return;
    context.go('/dashboard');
  }

  Future<void> _next() async {
    if (_index < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _openBalanceStepOrFinish();
  }

  Future<void> _skip() async {
    if (_showBalanceStep) {
      await _finish();
      return;
    }
    await _openBalanceStepOrFinish();
  }

  Future<void> _openBalanceStepOrFinish() async {
    if (_checking) return;

    setState(() => _checking = true);
    final hasAnyTransaction =
        await ref.read(databaseProvider).hasAnyTransaction();
    if (!mounted) return;
    setState(() => _checking = false);

    if (hasAnyTransaction) {
      await _finish();
      return;
    }
    setState(() => _showBalanceStep = true);
  }

  Future<void> _saveInitialBalance() async {
    if (_saving) return;

    final amount = parseAmount(_amountController.text);
    if (amount <= 0) {
      setState(() => _amountError = 'Nominal harus lebih dari nol.');
      return;
    }

    setState(() {
      _saving = true;
      _amountError = null;
    });

    try {
      await ref.read(ledgerServiceProvider).setInitialBalance(amount);
    } on LedgerException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _amountError = error.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _amountError = 'Terjadi kesalahan tak terduga.';
      });
      return;
    }

    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = isDark
        ? 'assets/branding/lockup_vertical_dark.png'
        : 'assets/branding/lockup_vertical_light.png';
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            children: [
              Row(
                children: [
                  if (_showBalanceStep)
                    TextButton.icon(
                      onPressed:
                          _saving ? null : () => setState(() => _showBalanceStep = false),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Kembali'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        _saving || _checking ? null : _skip,
                    child: Text(
                      'Lewati',
                      style: TextStyle(color: p.muted),
                    ),
                  ),
                ],
              ),
              Image.asset(logo, height: 100, fit: BoxFit.contain),
              const SizedBox(height: 8),
              Expanded(
                child: _showBalanceStep
                    ? _BalanceStep(
                        controller: _amountController,
                        error: _amountError,
                        enabled: !_saving,
                        onChanged: () {
                          if (_amountError != null) {
                            setState(() => _amountError = null);
                          }
                        },
                        onSubmitted: _saveInitialBalance,
                      )
                    : PageView.builder(
                        controller: _controller,
                        itemCount: _slides.length,
                        onPageChanged: (value) => setState(() => _index = value),
                        itemBuilder: (_, index) => _Slide(data: _slides[index]),
                      ),
              ),
              if (!_showBalanceStep) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index ? p.emerald : p.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _showBalanceStep
                      ? (_saving ? null : _saveInitialBalance)
                      : (_checking ? null : _next),
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.onAccent,
                          ),
                        )
                      : Text(
                          _showBalanceStep
                              ? 'Simpan & Mulai'
                              : (isLast ? 'Mulai' : 'Lanjut'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceStep extends StatelessWidget {
  const _BalanceStep({
    required this.controller,
    required this.error,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String? error;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: p.emeraldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 40,
              color: p.emerald,
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Berapa saldo awal Anda?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Masukkan uang tunai dan saldo rekening yang Anda miliki saat ini. '
              'Angka ini menjadi titik awal Saldo Utama.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.55, color: p.muted),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('initial-balance-field'),
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: const InputDecoration(
              labelText: 'Saldo awal',
              prefixText: 'Rp ',
              hintText: '0',
            ),
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmitted(),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: TextStyle(fontSize: 12, color: p.expense),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Bisa diubah nanti di Pengaturan → Penyesuaian Saldo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _Slide extends StatelessWidget {
  const _Slide({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: p.emeraldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 40, color: p.emerald),
          ),
          const SizedBox(height: 26),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              data.body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.55, color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}
