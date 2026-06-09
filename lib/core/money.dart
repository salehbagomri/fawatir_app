// أدوات النقود — مصدر موحّد للتنسيق والتحليل.
// المبالغ تُخزّن كوحدات صغرى (int، المبلغ × 100).

const Map<String, String> currencySymbols = {
  'USD': '\$',
  'SAR': 'ر.س',
  'YER': 'ر.ي',
  'AED': 'د.إ',
};

String symbolFor(String currency) => currencySymbols[currency] ?? currency;

double minorToDouble(int minor) => minor / 100;

/// "90.00" بدون عملة (للحقول وحقول التعديل).
String formatAmount(int minor) {
  final neg = minor < 0;
  final v = (minor.abs() / 100).toStringAsFixed(2);
  final parts = v.split('.');
  final intPart =
      parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${neg ? '-' : ''}$intPart.${parts[1]}';
}

/// "90.00 $" مع رمز العملة.
String formatMoney(int minor, String currency) =>
    '${formatAmount(minor)} ${symbolFor(currency)}';

/// تحليل نص مُدخل إلى وحدات صغرى. يدعم الأرقام العربية والفواصل والرموز.
int parseToMinor(String text) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  var s = text.trim();
  for (var i = 0; i < arabicDigits.length; i++) {
    s = s.replaceAll(arabicDigits[i], '$i');
  }
  s = s.replaceAll('٫', '.').replaceAll(',', '').replaceAll(' ', '');
  s = s.replaceAll(RegExp(r'[^0-9.]'), '');
  if (s.isEmpty) return 0;
  final value = double.tryParse(s) ?? 0;
  return (value * 100).round();
}
