import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_info.dart';
import '../../core/backup/backup_reminder.dart';
import '../../core/backup/backup_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/biometric_gate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/dialogs.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(mainBalanceProvider).valueOrNull ?? 0;
    final themeMode = ref.watch(themeModeProvider);
    final lastBackupAt = ref.watch(lastBackupAtProvider);
    final lockState = ref.watch(appLockControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const _SectionLabel('Tampilan'),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            title: 'Mode Tema',
            subtitle: switch (themeMode) {
              ThemeMode.light => 'Terang',
              ThemeMode.dark => 'Gelap',
              ThemeMode.system => 'Mengikuti sistem',
            },
            onTap: () => _pickThemeMode(context, ref),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Keamanan'),
          _SettingsTile(
            icon: lockState.enabled
                ? Icons.lock_rounded
                : Icons.lock_open_rounded,
            title: 'Kunci Aplikasi',
            subtitle: switch ((lockState.enabled, lockState.biometricEnabled)) {
              (false, _) => 'Belum aktif · pasang PIN agar data tidak terbuka',
              (true, true) => 'PIN + sidik jari aktif · auto-lock 30 detik',
              (true, false) => 'PIN aktif · auto-lock 30 detik',
            },
            onTap: () => _openLockFlow(context, ref, lockState),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Keuangan'),
          _SettingsTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Penyesuaian Saldo',
            subtitle: 'Saldo utama saat ini ${formatRupiah(balance)}',
            onTap: () => _showAdjustDialog(context, ref, balance),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.category_rounded,
            title: 'Kelola Kategori',
            subtitle: 'Tambah atau nonaktifkan kategori',
            onTap: () => context.push('/settings/categories'),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Data'),
          _SettingsTile(
            icon: Icons.cloud_upload_outlined,
            title: 'Backup Database',
            subtitle: lastBackupAt == null
                ? 'Belum pernah backup · simpan salinan .sqlite'
                : 'Terakhir ${formatDate(lastBackupAt)}',
            onTap: () => _exportBackup(context, ref),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Pulihkan Backup',
            subtitle: 'Ganti seluruh data dengan file backup .sqlite',
            onTap: () => _restoreBackup(context, ref),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Lainnya'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Tentang $appDisplayName',
            subtitle: 'Versi $appVersion · Offline-first',
            onTap: () => showAboutDialog(
              context: context,
              applicationName: appDisplayName,
              applicationVersion: appVersion,
              children: const [
                Text(
                  'Aplikasi keuangan pribadi yang bekerja sepenuhnya offline. '
                  'Seluruh data disimpan di perangkat Anda.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openLockFlow(BuildContext context, WidgetRef ref, AppLockState state) {
    if (!state.enabled) {
      context.push('/settings/lock?mode=create');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void close(void Function() after) {
          Navigator.of(sheetContext).pop();
          after();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.lock_rounded),
                title: const Text('Kunci sekarang'),
                subtitle: const Text('Langkah menuju layar PIN'),
                onTap: () =>
                    close(() => ref.read(appLockControllerProvider.notifier).lock()),
              ),
              ListTile(
                leading: const Icon(Icons.pin_rounded),
                title: const Text('Ganti PIN'),
                onTap: () => close(() => context.push('/settings/lock?mode=change')),
              ),
              ListTile(
                leading: Icon(
                  state.biometricEnabled
                      ? Icons.fingerprint_rounded
                      : Icons.no_encryption_rounded,
                ),
                title: Text(
                  state.biometricEnabled
                      ? 'Matikan sidik jari'
                      : 'Aktifkan sidik jari',
                ),
                subtitle: state.biometricStatus == BiometricStatus.available
                    ? null
                    : const Text('Belum ada sidik jari terdaftar di perangkat ini'),
                enabled: state.biometricStatus == BiometricStatus.available,
                onTap: () => close(
                  () => _toggleBiometric(ref, messenger, !state.biometricEnabled),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.lock_open_rounded),
                title: const Text(
                  'Matikan kunci aplikasi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () =>
                    close(() => context.push('/settings/lock?mode=disable')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleBiometric(
    WidgetRef ref,
    ScaffoldMessengerState messenger,
    bool enabled,
  ) async {
    messenger.hideCurrentSnackBar();
    try {
      await ref.read(appLockControllerProvider.notifier).setBiometric(enabled);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Sidik jari aktif.' : 'Sidik jari dimatikan, gunakan PIN.',
          ),
        ),
      );
    } on AppLockException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pickThemeMode(BuildContext context, WidgetRef ref) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (_) => const _ThemeModeDialog(),
    );
    if (selected != null) await saveThemeMode(ref, selected);
  }

  Future<void> _showAdjustDialog(
    BuildContext context,
    WidgetRef ref,
    int balance,
  ) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => AmountDialog(
        title: 'Penyesuaian Saldo',
        description:
            'Masukkan jumlah saldo utama yang benar saat ini. '
            'Selisihnya akan dicatat sebagai transaksi penyesuaian.',
        initialAmount: balance,
        confirmLabel: 'Simpan',
        onSubmit: (amount) =>
            ref.read(ledgerServiceProvider).adjustBalanceTo(amount),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final saved = await ref.read(backupServiceProvider).exportBackup();
      if (!context.mounted) return;
      _showMessage(
        context,
        saved ? 'Backup database berhasil disimpan.' : 'Backup dibatalkan.',
      );
    } on BackupException catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Gagal membuat backup: ${error.message}');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Gagal membuat backup: $error');
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Pulihkan Backup?',
      message:
          'Seluruh transaksi, tabungan, dan utang saat ini akan diganti '
          'dengan isi file backup. Data lama disalin ke file pengaman '
          'terlebih dahulu, tetapi penggantian ini tidak bisa dibatalkan '
          'dari aplikasi.',
      confirmLabel: 'Pilih File',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BusyDialog(message: 'Memulihkan data...'),
    );

    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final restored = await ref.read(backupServiceProvider).restoreBackup();
      navigator.pop();
      if (!context.mounted) return;
      _showMessage(
        context,
        restored
            ? 'Backup berhasil dipulihkan.'
            : 'Pemulihan dibatalkan.',
      );
    } on BackupException catch (error) {
      navigator.pop();
      if (!context.mounted) return;
      _showMessage(context, 'Gagal memulihkan: ${error.message}');
    } catch (error) {
      navigator.pop();
      if (!context.mounted) return;
      _showMessage(context, 'Gagal memulihkan: $error');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: p.muted,
        ),
      ),
    );
  }
}

class _ThemeModeDialog extends ConsumerWidget {
  const _ThemeModeDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return AlertDialog(
      title: const Text(
        'Mode Tema',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            label: 'Mengikuti sistem',
            mode: ThemeMode.system,
            selected: mode == ThemeMode.system,
          ),
          _ThemeOption(
            label: 'Terang',
            mode: ThemeMode.light,
            selected: mode == ThemeMode.light,
          ),
          _ThemeOption(
            label: 'Gelap',
            mode: ThemeMode.dark,
            selected: mode == ThemeMode.dark,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.mode,
    required this.selected,
  });

  final String label;
  final ThemeMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.circle_outlined,
        color: selected ? p.emerald : p.line,
      ),
      onTap: () => Navigator.of(context).pop(mode),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: p.emeraldSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: p.emerald),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: p.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}

class _BusyDialog extends StatelessWidget {
  const _BusyDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
