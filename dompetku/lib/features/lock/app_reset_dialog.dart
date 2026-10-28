import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/app_lock_controller.dart';
import '../../core/security/app_reset_service.dart';
import '../../core/widgets/dialogs.dart';

/// Satu-satunya jalur pemulihan saat PIN lupa: hapus seluruh data.
Future<void> showAppResetDialog(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Reset Aplikasi?',
    message:
        'Seluruh transaksi, tabungan, utang, dan PIN akan dihapus permanen dari '
        'perangkat ini. Data hanya bisa kembali bila Anda menyimpan file backup .sqlite.',
    confirmLabel: 'Hapus Semua Data',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final router = GoRouter.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BusyDialog(),
  );

  try {
    await wipeAppData(ref);
    await ref.read(appLockControllerProvider.notifier).clearConfig();
  } catch (error) {
    if (navigator.canPop()) navigator.pop();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Reset gagal: $error')));
    return;
  }

  if (navigator.canPop()) navigator.pop();
  router.go('/onboarding');
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Aplikasi sudah disetel ulang.')),
    );
}

class _BusyDialog extends StatelessWidget {
  const _BusyDialog();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Menghapus data...',
                style: TextStyle(fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
