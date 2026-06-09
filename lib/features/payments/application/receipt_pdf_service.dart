import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/pdf/receipt_pdf.dart';
import '../../../shared/pdf/invoice_pdf.dart' show CompanyInfo;
import '../../../core/money.dart';
import '../data/payment_repository.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../clients/data/client_repository.dart';
import '../../company/data/company_repository.dart';

final receiptPdfServiceProvider = Provider<Future<ReceiptPdfData> Function(int)>((ref) {
  return (paymentId) => buildReceiptPdfData(ref, paymentId);
});

Future<ReceiptPdfData> buildReceiptPdfData(Ref ref, int paymentId) async {
  final payRepo = ref.read(paymentRepositoryProvider);
  final payment = await payRepo.getPayment(paymentId);
  if (payment == null) throw StateError('التحصيل غير موجود');
  final client =
      await ref.read(clientRepositoryProvider).getClient(payment.clientId);
  final company = await ref.read(companyRepositoryProvider).getCompany();

  Uint8List? logoBytes;
  final lp = company?.logoPath;
  if (lp != null && await File(lp).exists()) {
    logoBytes = await File(lp).readAsBytes();
  }

  String? invoiceNumber, invoiceCurrency, fxNote, settlementNote;
  int? invoiceTotalMinor;

  if (payment.invoiceId != null) {
    final invoice =
        await ref.read(invoiceRepositoryProvider).getInvoice(payment.invoiceId!);
    if (invoice != null) {
      invoiceNumber = invoice.number;
      invoiceTotalMinor = invoice.totalMinor;
      invoiceCurrency = invoice.currency;
      if (payment.currency != invoice.currency && invoice.fxRateToAccount != 0) {
        final equiv = (payment.amountMinor * payment.fxRateToAccount) /
            invoice.fxRateToAccount;
        fxNote = 'يعادل ${formatMoney(equiv.round(), invoice.currency)}';
      }
      final remaining = await payRepo.invoiceRemainingMinor(invoice.id);
      settlementNote = remaining <= 0
          ? 'مسدّدة بالكامل'
          : 'متبقٍ ${formatMoney(remaining, invoice.currency)}';
    }
  }

  final number =
      'REC-${payment.paymentDate.year}-${paymentId.toString().padLeft(4, '0')}';

  return ReceiptPdfData(
    company: CompanyInfo(
      name: company?.name ?? '',
      logoBytes: logoBytes,
      address: company?.address,
      phone: company?.phone,
      email: company?.email,
      bankDetails: company?.bankDetails,
    ),
    receiptNumber: number,
    date: payment.paymentDate,
    receivedFrom: client?.name ?? '',
    amountMinor: payment.amountMinor,
    currency: payment.currency,
    method: payment.method,
    invoiceNumber: invoiceNumber,
    invoiceTotalMinor: invoiceTotalMinor,
    invoiceCurrency: invoiceCurrency,
    fxNote: fxNote,
    settlementNote: settlementNote,
    notes: 'شكراً لتعاملكم. هذا السند تأكيد باستلام المبلغ أعلاه.',
  );
}
