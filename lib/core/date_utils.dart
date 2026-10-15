/// دالة تنسيق التاريخ الموحدة بصيغة YYYY/MM/DD
String formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

/// دالة تنسيق التاريخ والوقت الموحدة بصيغة YYYY/MM/DD HH:MM
String formatDateTime(DateTime date) {
  final d = formatDate(date);
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '$d $h:$m';
}
