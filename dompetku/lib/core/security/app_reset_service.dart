import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';

/// Menyetel ulang aplikasi: hapus database dan seluruh preferensi.
///
/// Dipakai saat pengguna lupa PIN, karena hash PIN ikut hilang sehingga
/// tidak ada jalan pintas untuk membuka data lama.
Future<void> wipeAppData(WidgetRef ref) async {
  final database = ref.read(databaseProvider);
  await database.close();

  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}${Platform.pathSeparator}dompetku.sqlite';
  for (final suffix in const ['', '-wal', '-shm']) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.delete();
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  ref.invalidate(databaseProvider);
  await ref.read(databaseProvider).customSelect('SELECT 1').getSingle();
}
