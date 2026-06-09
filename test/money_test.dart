import 'package:flutter_test/flutter_test.dart';
import 'package:fawatir/core/money.dart';

void main() {
  group('Money Utilities', () {
    test('formatMoney formats correctly', () {
      expect(formatMoney(9000, 'USD'), '90.00 \$');
      expect(formatMoney(1234567, 'SAR'), '12,345.67 ر.س');
    });

    test('parseToMinor parses correctly', () {
      expect(parseToMinor('90.50'), 9050);
      expect(parseToMinor('١٢٣'), 12300);
    });
  });
}
