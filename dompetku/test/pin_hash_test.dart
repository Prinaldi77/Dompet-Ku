import 'dart:convert';

import 'package:dompetku/core/security/pin_hash.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(String base64Value) => base64Decode(base64Value)
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();

void main() {
  group('hashPin (PBKDF2-HMAC-SHA256)', () {
    final salt = base64Encode(utf8.encode('salt'));

    test('cocok dengan vektor standar untuk 1 dan 2 iterasi', () {
      expect(
        _hex(hashPin('password', salt, iterations: 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        _hex(hashPin('password', salt, iterations: 2)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('salt berbeda menghasilkan hash berbeda', () {
      final a = hashPin('2468', generatePinSalt());
      final b = hashPin('2468', generatePinSalt());
      expect(a, isNot(b));
    });

    test('verifyPin menerima PIN benar dan menolak PIN salah', () {
      final salt = generatePinSalt();
      final hash = hashPin('2468', salt);
      expect(verifyPin('2468', salt, hash), isTrue);
      expect(verifyPin('2469', salt, hash), isFalse);
    });
  });

  group('pinValidationError', () {
    test('menolak PIN terlalu pendek atau terlalu panjang', () {
      expect(pinValidationError('123'), contains('4–6'));
      expect(pinValidationError('1234567'), contains('4–6'));
    });

    test('menolak angka berulang dan urutan', () {
      expect(pinValidationError('1111'), contains('sama semua'));
      expect(pinValidationError('1234'), contains('urutan'));
      expect(pinValidationError('9876'), contains('urutan'));
      expect(pinValidationError('234567'), contains('urutan'));
    });

    test('menerima PIN acak 4 sampai 6 angka', () {
      expect(pinValidationError('5183'), isEmpty);
      expect(pinValidationError('702941'), isEmpty);
    });
  });
}
