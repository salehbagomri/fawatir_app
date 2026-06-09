import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db/database.dart';
import '../../../data/db/tables.dart';

/// مستودع التحصيلات — يسجّل الدفع ويحدّث حالة الفاتورة ويحسب الرصيد.
/// المقارنة دائماً بعملة حساب العميل عبر fxRateToAccount لدعم اختلاف العملة.
class PaymentRepository {
  final AppDatabase db;
  PaymentRepository(this.db);

  Future<int> recordPayment({
    required int clientId,
    int? invoiceId,
    required int amountMinor,
    required String currency,
    required DateTime date,
    double fxRateToAccount = 1.0,
    String? method,
    String? notes,
  }) async {
    final id = await db.into(db.payments).insert(PaymentsCompanion.insert(
          clientId: clientId,
          invoiceId: Value(invoiceId),
          paymentDate: date,
          amountMinor: amountMinor,
          currency: currency,
          fxRateToAccount: Value(fxRateToAccount),
          method: Value(method),
          notes: Value(notes),
        ));
    if (invoiceId != null) {
      await _recomputeInvoiceStatus(invoiceId);
    }
    return id;
  }

  Future<void> _recomputeInvoiceStatus(int invoiceId) async {
    final invoice = await (db.select(db.invoices)
          ..where((i) => i.id.equals(invoiceId)))
        .getSingle();
    final pays = await (db.select(db.payments)
          ..where((p) => p.invoiceId.equals(invoiceId)))
        .get();

    if (invoice.status == InvoiceStatus.draft ||
        invoice.status == InvoiceStatus.cancelled) {
      return;
    }

    final totalInAccount = invoice.totalMinor * invoice.fxRateToAccount;
    final paidInAccount =
        pays.fold<double>(0, (s, p) => s + p.amountMinor * p.fxRateToAccount);

    InvoiceStatus status;
    if (paidInAccount <= 0) {
      status = InvoiceStatus.sent;
    } else if (paidInAccount + 1 >= totalInAccount) {
      status = InvoiceStatus.paid;
    } else {
      status = InvoiceStatus.partiallyPaid;
    }

    await (db.update(db.invoices)..where((i) => i.id.equals(invoiceId)))
        .write(InvoicesCompanion(status: Value(status)));
  }

  /// رصيد حساب العميل (الرصيد المتدحرج) بعملة حسابه.
  Future<int> clientAccountBalanceMinor(int clientId) async {
    final invs = await (db.select(db.invoices)
          ..where((i) =>
              i.clientId.equals(clientId) &
              i.status.equals(InvoiceStatus.cancelled.index).not() &
              i.status.equals(InvoiceStatus.draft.index).not()))
        .get();
    final pays = await (db.select(db.payments)
          ..where((p) => p.clientId.equals(clientId)))
        .get();

    final debit =
        invs.fold<double>(0, (s, i) => s + i.totalMinor * i.fxRateToAccount);
    final credit =
        pays.fold<double>(0, (s, p) => s + p.amountMinor * p.fxRateToAccount);
    return (debit - credit).round();
  }

  /// المتبقي على فاتورة محددة بعملتها.
  Future<int> invoiceRemainingMinor(int invoiceId) async {
    final invoice = await (db.select(db.invoices)
          ..where((i) => i.id.equals(invoiceId)))
        .getSingle();
    final pays = await (db.select(db.payments)
          ..where((p) => p.invoiceId.equals(invoiceId)))
        .get();
    final paidInAccount =
        pays.fold<double>(0, (s, p) => s + p.amountMinor * p.fxRateToAccount);
    final paidInInvoiceCurrency = invoice.fxRateToAccount == 0
        ? 0
        : paidInAccount / invoice.fxRateToAccount;
    final remaining = invoice.totalMinor - paidInInvoiceCurrency;
    return remaining.round();
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(ref.watch(databaseProvider)),
);

/// هل الفاتورة متأخرة؟ (يُحسب عند العرض، لا يُخزّن)
bool isInvoiceOverdue(Invoice i) =>
    i.dueDate != null &&
    DateTime.now().isAfter(i.dueDate!) &&
    i.status != InvoiceStatus.paid &&
    i.status != InvoiceStatus.cancelled;
