import 'package:dompetku/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatRupiah memakai simbol Rp dan pemisah ribuan', () {
    expect(formatRupiah(12450000), 'Rp 12.450.000');
  });

  test('parseAmount mengabaikan pemisah ribuan', () {
    expect(parseAmount('12.450.000'), 12450000);
  });

  test('ThousandsInputFormatter menambahkan pemisah ribuan', () {
    final formatter = ThousandsInputFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '12450000'),
    );
    expect(result.text, '12.450.000');
  });
}
