import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../providers/app_providers.dart';
import 'backup_reminder.dart';

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupService {
  const BackupService(this._ref);

  final Ref _ref;

  static const _schemaVersion = 1;
  static const _requiredTables = {
    'categories',
    'transactions',
    'savings_goals',
    'saving_logs',
    'debts',
    'debt_payments',
  };

  /// Mengekspor salinan database ke lokasi yang dipilih pengguna.
  /// Mengembalikan false bila pengguna membatalkan dialog.
  Future<bool> exportBackup() async {
    final db = _ref.read(databaseProvider);
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

    final source = await _databaseFile();
    if (!await source.exists()) {
      throw const BackupException('Database belum tersedia.');
    }

    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final path = await FilePicker.saveFile(
      dialogTitle: 'Simpan backup DompetKu',
      fileName: 'dompetku-$stamp.sqlite',
      type: FileType.any,
      bytes: await source.readAsBytes(),
    );
    if (path == null) return false;

    await markBackupDone(_ref);
    return true;
  }

  /// Memilih file backup, memvalidasinya, lalu mengganti database aktif.
  /// Mengembalikan false bila pengguna membatalkan pemilihan file.
  Future<bool> restoreBackup() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Pilih backup DompetKu (.sqlite)',
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return false;

    final picked = result.files.first;
    final bytes = picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) {
      throw const BackupException('File backup tidak dapat dibaca.');
    }

    await _validate(bytes);

    await _ref.read(databaseProvider).close();
    final target = await _databaseFile();
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('${target.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
    await target.writeAsBytes(bytes, flush: true);

    _ref.invalidate(databaseProvider);
    // Tunggu database baru siap sebelum UI melanjutkan.
    await _ref.read(databaseProvider).customSelect('SELECT 1').getSingle();
    return true;
  }

  Future<File> _databaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}dompetku.sqlite');
  }

  Future<void> _validate(Uint8List bytes) async {
    const header = 'SQLite format 3';
    if (bytes.length < 100 ||
        String.fromCharCodes(bytes.take(header.length)) != header) {
      throw const BackupException('File bukan database SQLite yang valid.');
    }

    final dir = await getTemporaryDirectory();
    final temp = File(
      '${dir.path}${Platform.pathSeparator}restore-'
      '${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    Database? raw;
    try {
      await temp.writeAsBytes(bytes, flush: true);
      raw = sqlite3.open(temp.path);

      final integrity = raw.select('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const BackupException('File backup rusak (integrity check gagal).');
      }

      final version = raw.select('PRAGMA user_version').first.values.first;
      if (version != _schemaVersion) {
        throw BackupException(
          'Versi backup ($version) tidak didukung aplikasi ini.',
        );
      }

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row.values.first)
          .toSet();
      if (!_requiredTables.every(tables.contains)) {
        throw const BackupException('File bukan backup DompetKu.');
      }
    } on SqliteException catch (error) {
      throw BackupException('Gagal membaca file backup: ${error.message}');
    } finally {
      raw?.dispose();
      if (await temp.exists()) await temp.delete();
    }
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref);
});
