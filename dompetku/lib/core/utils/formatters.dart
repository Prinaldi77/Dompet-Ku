import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final NumberFormat _decimal = NumberFormat.decimalPattern('id_ID');

String formatRupiah(int value) => _rupiah.format(value);

String formatSignedRupiah(int value, {required bool isIncome}) =>
    '${isIncome ? '+' : '-'}${_rupiah.format(value.abs())}';

String formatDigits(int value) => _decimal.format(value);

String formatDate(DateTime date) => DateFormat('d MMM yyyy', 'id_ID').format(date);

String formatMonth(DateTime date) =>
    DateFormat('MMMM yyyy', 'id_ID').format(date);

String formatShortDate(DateTime date) =>
    DateFormat('d MMM', 'id_ID').format(date);

int parseAmount(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Menampilkan ribuan otomatis saat pengguna mengetik nominal.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = _decimal.format(int.parse(trimmed));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
