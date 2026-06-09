import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/pdf/statement_pdf.dart';
import '../../../shared/pdf/invoice_pdf.dart' show CompanyInfo;
import '../data/statement_repository.dart';
import '../../company/data/company_repository.dart';

final statementPdfServiceProvider = Provider<
    Future<StatementPdfData> Function(int,
        {DateTime? from, DateTime? to})>((ref) {
  return (clientId, {from, to}) =>
      buildStatementPdfData(ref, clientId, from: from, to: to);
});

Future<StatementPdfData> buildStatementPdfData(Ref ref, int clientId,
    {DateTime? from, DateTime? to}) async {
  final statement = await ref
      .read(statementRepositoryProvider)
      .buildStatement(clientId, from: from, to: to);
  final company = await ref.read(companyRepositoryProvider).getCompany();

  Uint8List? logoBytes;
  final lp = company?.logoPath;
  if (lp != null && await File(lp).exists()) {
    logoBytes = await File(lp).readAsBytes();
  }

  return StatementPdfData(
    company: CompanyInfo(
      name: company?.name ?? '',
      logoBytes: logoBytes,
      address: company?.address,
      phone: company?.phone,
      email: company?.email,
      bankDetails: company?.bankDetails,
    ),
    clientName: statement.clientName,
    currency: statement.accountCurrency,
    from: statement.from,
    to: statement.to,
    openingBalanceMinor: statement.openingBalanceMinor,
    totalDebitMinor: statement.totalDebitMinor,
    totalCreditMinor: statement.totalCreditMinor,
    closingBalanceMinor: statement.closingBalanceMinor,
    entries: statement.entries
        .map((e) => StatementPdfEntry(
              date: e.date,
              reference: e.reference,
              debitMinor: e.debitMinor,
              creditMinor: e.creditMinor,
              runningBalanceMinor: e.runningBalanceMinor,
              isInvoice: e.type == StatementEntryType.invoice,
            ))
        .toList(),
  );
}
