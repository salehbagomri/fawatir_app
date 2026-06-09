import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert and read client', () async {
    final clientId = await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('عميل تجريبي'),
        accountCurrency: Value('USD'),
      ),
    );

    final client = await (db.select(db.clients)..where((tbl) => tbl.id.equals(clientId))).getSingle();

    expect(client.name, 'عميل تجريبي');
    expect(client.accountCurrency, 'USD');
  });

  test('recordPayment recomputes invoice status to paid', () async {
    // Insert a client
    final clientId = await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('عميل تجريبي'),
        accountCurrency: Value('USD'),
      ),
    );

    // Insert an invoice (status: sent, totalMinor: 5000, currency: 'USD', fxRateToAccount: 1.0)
    final invoiceId = await db.into(db.invoices).insert(
      InvoicesCompanion(
        clientId: Value(clientId),
        number: const Value('INV-2026-001'),
        issueDate: Value(DateTime.now()),
        status: const Value(InvoiceStatus.sent),
        totalMinor: const Value(5000),
        currency: const Value('USD'),
        fxRateToAccount: const Value(1.0),
      ),
    );

    // Record payment using PaymentRepository
    final paymentRepo = PaymentRepository(db);
    await paymentRepo.recordPayment(
      clientId: clientId,
      invoiceId: invoiceId,
      amountMinor: 5000,
      currency: 'USD',
      date: DateTime.now(),
      fxRateToAccount: 1.0,
    );

    // Verify invoice status
    final invoice = await (db.select(db.invoices)..where((tbl) => tbl.id.equals(invoiceId))).getSingle();
    expect(invoice.status, InvoiceStatus.paid);

    // Check client balance (should be 0 since invoice 5000 is fully paid by payment 5000)
    final balance = await paymentRepo.clientAccountBalanceMinor(clientId);
    expect(balance, 0);
  });
}
