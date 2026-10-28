import 'dart:io';
import 'dart:typed_data';

import 'package:dompetku/core/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('replaceDatabaseFile', () {
    late Directory dir;
    late File target;
    late File safety;

    Future<void> writeOldDatabase() =>
        target.writeAsBytes(Uint8List.fromList(List.filled(8, 0xAA)));

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('dompetku_restore_');
      target = File('${dir.path}${Platform.pathSeparator}dompetku.sqlite');
      safety = File('${target.path}${BackupService.preRestoreSuffix}');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('menyimpan salinan pra-restore sebelum menimpa database', () async {
      await writeOldDatabase();

      await BackupService.replaceDatabaseFile(
        target,
        Uint8List.fromList([1, 2, 3]),
      );

      expect(await safety.readAsBytes(), List.filled(8, 0xAA));
      expect(await target.readAsBytes(), [1, 2, 3]);
    });

    test('gagal menulis mengembalikan database lama utuh', () async {
      await writeOldDatabase();

      await expectLater(
        BackupService.replaceDatabaseFile(
          target,
          Uint8List.fromList([1, 2, 3]),
          writer: (file, bytes) async {
            await file.writeAsBytes(bytes.sublist(0, 1), flush: true);
            throw FileSystemException('No space left on device');
          },
        ),
        throwsA(isA<BackupException>()),
      );

      expect(await target.readAsBytes(), List.filled(8, 0xAA));
    });

    test('database aktif belum ada: kegagalan ditulis apa adanya', () async {
      await expectLater(
        BackupService.replaceDatabaseFile(
          target,
          Uint8List.fromList([1, 2, 3]),
          writer: (_, __) async => throw FileSystemException('gagal'),
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await target.exists(), isFalse);
      expect(await safety.exists(), isFalse);
    });

    test('salinan sisa restore lama dibuang saat database aktif hilang', () async {
      await safety.writeAsBytes([9, 9, 9], flush: true);

      await BackupService.replaceDatabaseFile(
        target,
        Uint8List.fromList([1, 2, 3]),
      );

      expect(await safety.exists(), isFalse);
      expect(await target.readAsBytes(), [1, 2, 3]);
    });
  });
}
