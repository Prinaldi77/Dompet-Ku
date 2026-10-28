import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const int pinIterations = 30000;
const int pinKeyLength = 32;
const int pinLengthMin = 4;
const int pinLengthMax = 6;

String generatePinSalt() {
  final random = Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(16, (_) => random.nextInt(256)),
  );
  return base64Encode(bytes);
}

/// PBKDF2-HMAC-SHA256 (RFC 2898). Panggil dari isolate agar UI tidak tersendat.
String hashPin(
  String pin,
  String saltBase64, {
  int iterations = pinIterations,
}) {
  final salt = base64Decode(saltBase64);
  final hmac = Hmac(sha256, utf8.encode(pin));

  final block = Uint8List(salt.length + 4)..setRange(0, salt.length, salt);
  final output = Uint8List(pinKeyLength);

  var written = 0;
  var blockIndex = 1;
  while (written < pinKeyLength) {
    block[salt.length] = (blockIndex >> 24) & 0xFF;
    block[salt.length + 1] = (blockIndex >> 16) & 0xFF;
    block[salt.length + 2] = (blockIndex >> 8) & 0xFF;
    block[salt.length + 3] = blockIndex & 0xFF;

    var u = hmac.convert(block).bytes;
    final accumulator = Uint8List.fromList(u);
    for (var round = 1; round < iterations; round++) {
      u = hmac.convert(u).bytes;
      for (var i = 0; i < accumulator.length; i++) {
        accumulator[i] ^= u[i];
      }
    }

    final take = min(32, pinKeyLength - written);
    output.setRange(written, written + take, accumulator);
    written += take;
    blockIndex++;
  }

  return base64Encode(output);
}

bool verifyPin(String pin, String saltBase64, String expectedHash) {
  return _constantEquals(hashPin(pin, saltBase64), expectedHash);
}

bool _constantEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

const _sequentialDigits = '0123456789';

/// Returns pesan kesalahan dalam Bahasa, atau string kosong bila PIN valid.
String pinValidationError(String pin) {
  if (pin.length < pinLengthMin || pin.length > pinLengthMax) {
    return 'PIN harus $pinLengthMin–$pinLengthMax angka.';
  }
  if (!pin.codeUnits.every((c) => c >= 48 && c <= 57)) {
    return 'PIN hanya berisi angka.';
  }
  if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
    return 'PIN tidak boleh angka yang sama semua.';
  }
  if (_sequentialDigits.contains(pin) ||
      _sequentialDigits.contains(pin.split('').reversed.join())) {
    return 'PIN tidak boleh urutan angka.';
  }
  return '';
}
