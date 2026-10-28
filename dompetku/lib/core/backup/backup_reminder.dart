import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';

const int backupReminderDays = 30;
const int backupReminderMinTransactions = 20;

const _lastBackupKey = 'last_backup_at';
const _firstOpenKey = 'first_open_at';

/// Waktu backup terakhir pada perangkat ini. `null` berarti belum pernah.
final lastBackupAtProvider = StateProvider<DateTime?>((ref) => null);

/// Acuan umur data ketika pengguna belum pernah melakukan backup.
final firstOpenAtProvider = StateProvider<DateTime>((ref) => DateTime.now());

bool shouldRemindBackup({
  required int transactionCount,
  required DateTime? lastBackupAt,
  required DateTime firstOpenAt,
  required DateTime now,
}) {
  if (transactionCount < backupReminderMinTransactions) return false;
  final reference = lastBackupAt ?? firstOpenAt;
  return now.difference(reference) > const Duration(days: backupReminderDays);
}

Future<DateTime?> loadLastBackupAt() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_lastBackupKey);
  return stored == null ? null : DateTime.tryParse(stored);
}

Future<DateTime> loadOrCreateFirstOpenAt() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_firstOpenKey);
  final parsed = stored == null ? null : DateTime.tryParse(stored);
  if (parsed != null) return parsed;

  final now = DateTime.now();
  await prefs.setString(_firstOpenKey, now.toIso8601String());
  return now;
}

Future<DateTime> saveBackupTimestamp() async {
  final now = DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_lastBackupKey, now.toIso8601String());
  return now;
}

Future<void> markBackupDone(Ref ref) async {
  final now = await saveBackupTimestamp();
  ref.read(lastBackupAtProvider.notifier).state = now;
}

final backupReminderProvider = Provider<bool>((ref) {
  final count = ref.watch(transactionCountProvider).valueOrNull ?? 0;
  return shouldRemindBackup(
    transactionCount: count,
    lastBackupAt: ref.watch(lastBackupAtProvider),
    firstOpenAt: ref.watch(firstOpenAtProvider),
    now: DateTime.now(),
  );
});
