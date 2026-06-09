import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/shared/pdf/invoice_pdf.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';
import 'package:fawatir/features/clients/data/client_repository.dart';
import 'package:fawatir/features/company/data/company_repository.dart';

final invoicePdfServiceProvider = Provider<Future<InvoicePdfData> Function(int)>((ref) {
  return (invoiceId) => buildInvoicePdfData(ref, invoiceId);
});

/// يبني InvoicePdfData من معرّف الفاتورة عبر المستودعات.
Future<InvoicePdfData> buildInvoicePdfData(Ref ref, int invoiceId) async {
  final invRepo = ref.read(invoiceRepositoryProvider);
  final invoice = await invRepo.getInvoice(invoiceId);
  if (invoice == null) throw StateError('الفاتورة غير موجودة');
  final items = await invRepo.getItems(invoiceId);
  final client =
      await ref.read(clientRepositoryProvider).getClient(invoice.clientId);
  final company = await ref.read(companyRepositoryProvider).getCompany();

  Uint8List? logoBytes;
  final lp = company?.logoPath;
  if (lp != null && lp.isNotEmpty && await File(lp).exists()) {
    logoBytes = await File(lp).readAsBytes();
  }

  return InvoicePdfData(
    company: CompanyInfo(
      name: company?.name ?? '',
      logoBytes: logoBytes,
      address: company?.address,
      phone: company?.phone,
      email: company?.email,
      bankDetails: company?.bankDetails,
    ),
    client: ClientInfo(
      name: client?.name ?? '',
      contactPerson: client?.contactPerson,
      phone: client?.phone,
      address: client?.address,
    ),
    number: invoice.number,
    issueDate: invoice.issueDate,
    dueDate: invoice.dueDate,
    currency: invoice.currency,
    items: items
        .map((it) => InvoiceLine(
              description: it.description,
              quantity: it.quantity,
              unitPriceMinor: it.unitPriceMinor,
            ))
        .toList(),
    notes: invoice.notes,
  );
}
