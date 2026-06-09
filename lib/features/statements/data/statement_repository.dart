import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db/database.dart';
import '../../../data/db/tables.dart';

enum StatementEntryType { invoice, payment }

class StatementEntry {
  final DateTime date;
  final StatementEntryType type;
  final String reference;
  final int debitMinor;
  final int creditMinor;
  final int runningBalanceMinor;
  const StatementEntry({
    required this.date,
    required this.type,
    required this.reference,
    required this.debitMinor,
    required this.creditMinor,
    required this.runningBalanceMinor,
  });
}

class Statement {
  final int clientId;
  final String clientName;
  final String accountCurrency;
  final DateTime? from;
  final DateTime? to;
  final int openingBalanceMinor;
  final int closingBalanceMinor;
  final int totalDebitMinor;
  final int totalCreditMinor;
  final List<StatementEntry> entries;
  const Statement({
    required this.clientId,
    required this.clientName,
    required this.accountCurrency,
    required this.from,
    required this.to,
    required this.openingBalanceMinor,
    required this.closingBalanceMinor,
    required this.totalDebitMinor,
    required this.totalCreditMinor,
    required this.entries,
  });
}

class _Raw {
  final DateTime date;
  final StatementEntryType type;
  final String reference;
  final int debit;
  final int credit;
  _Raw(this.date, this.type, this.reference, this.debit, this.credit);
}

class StatementRepository {
  final AppDatabase db;
  StatementRepository(this.db);

  Future<Statement> buildStatement(int clientId,
      {DateTime? from, DateTime? to}) async {
    final client =
        await (db.select(db.clients)..where((c) => c.id.equals(clientId)))
            .getSingle();

    final invoices = await (db.select(db.invoices)
          ..where((i) =>
              i.clientId.equals(clientId) &
              i.status.equals(InvoiceStatus.draft.index).not() &
              i.status.equals(InvoiceStatus.cancelled.index).not()))
        .get();
    final payments = await (db.select(db.payments)
          ..where((p) => p.clientId.equals(clientId)))
        .get();

    final all = <_Raw>[];
    for (final inv in invoices) {
      all.add(_Raw(inv.issueDate, StatementEntryType.invoice,
          'فاتورة ${inv.number}', (inv.totalMinor * inv.fxRateToAccount).round(), 0));
    }
    for (final p in payments) {
      final receiptNumber =
          'REC-${p.paymentDate.year}-${p.id.toString().padLeft(4, '0')}';
      all.add(_Raw(
          p.paymentDate,
          StatementEntryType.payment,
          'سند تحصيل $receiptNumber',
          0,
          (p.amountMinor * p.fxRateToAccount).round()));
    }
    all.sort((a, b) => a.date.compareTo(b.date));

    int opening = 0;
    for (final r in all) {
      if (from != null && r.date.isBefore(from)) {
        opening += r.debit - r.credit;
      }
    }

    final entries = <StatementEntry>[];
    int running = opening;
    int totalDebit = 0, totalCredit = 0;
    for (final r in all) {
      final afterFrom = from == null || !r.date.isBefore(from);
      final beforeTo = to == null || !r.date.isAfter(to);
      if (afterFrom && beforeTo) {
        running += r.debit - r.credit;
        totalDebit += r.debit;
        totalCredit += r.credit;
        entries.add(StatementEntry(
          date: r.date,
          type: r.type,
          reference: r.reference,
          debitMinor: r.debit,
          creditMinor: r.credit,
          runningBalanceMinor: running,
        ));
      }
    }

    return Statement(
      clientId: clientId,
      clientName: client.name,
      accountCurrency: client.accountCurrency,
      from: from,
      to: to,
      openingBalanceMinor: opening,
      closingBalanceMinor: running,
      totalDebitMinor: totalDebit,
      totalCreditMinor: totalCredit,
      entries: entries,
    );
  }
}

final statementRepositoryProvider = Provider<StatementRepository>(
    (ref) => StatementRepository(ref.watch(databaseProvider)));
