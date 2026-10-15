import 'package:flutter/material.dart';
import 'package:fawatir/data/db/tables.dart';

Color invoiceStatusColor(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return Colors.grey.shade600;
    case InvoiceStatus.sent:
      return Colors.blue.shade700;
    case InvoiceStatus.paid:
      return Colors.green.shade700;
    case InvoiceStatus.partiallyPaid:
      return Colors.orange.shade800;
    case InvoiceStatus.overdue:
      return Colors.red.shade700;
    case InvoiceStatus.cancelled:
      return Colors.grey.shade600;
  }
}

String invoiceStatusLabel(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return 'مسودة';
    case InvoiceStatus.sent:
      return 'مرسلة';
    case InvoiceStatus.paid:
      return 'مدفوعة';
    case InvoiceStatus.partiallyPaid:
      return 'مدفوعة جزئياً';
    case InvoiceStatus.overdue:
      return 'متأخرة';
    case InvoiceStatus.cancelled:
      return 'ملغاة';
  }
}

IconData invoiceStatusIcon(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return Icons.edit_note_rounded;
    case InvoiceStatus.sent:
      return Icons.send_rounded;
    case InvoiceStatus.paid:
      return Icons.check_circle_rounded;
    case InvoiceStatus.partiallyPaid:
      return Icons.pie_chart_outline_rounded;
    case InvoiceStatus.overdue:
      return Icons.warning_amber_rounded;
    case InvoiceStatus.cancelled:
      return Icons.cancel_outlined;
  }
}
