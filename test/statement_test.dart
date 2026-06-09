import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/payments/data/payment_repository.dart';
import 'package:fawatir/features/statements/data/statement_repository.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;
  late PaymentRepository paymentRepo;
  late StatementRepository statementRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    paymentRepo = PaymentRepository(db);
    statementRepo = StatementRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Statement logic calculates debit, credit, closing balance and matches client account balance', () async {
    // 1. Insert a client with currency USD
    final clientId = await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('عميل تجريبي مالي'),
        accountCurrency: Value('USD'),
      ),
    );

    // 2. Insert an invoice (status: sent, totalMinor: 10000, currency: 'USD', fxRateToAccount: 1.0)
    final invoiceId = await db.into(db.invoices).insert(
      InvoicesCompanion(
        clientId: Value(clientId),
        number: const Value('INV-2026-999'),
        issueDate: Value(DateTime.now().subtract(const Duration(days: 2))),
        status: const Value(InvoiceStatus.sent),
        totalMinor: const Value(10000),
        currency: const Value('USD'),
        fxRateToAccount: const Value(1.0),
      ),
    );

    // 3. Record a payment of 6000
    await paymentRepo.recordPayment(
      clientId: clientId,
      invoiceId: invoiceId,
      amountMinor: 6000,
      currency: 'USD',
      date: DateTime.now(),
      fxRateToAccount: 1.0,
    );

    // 4. Build the statement
    final statement = await statementRepo.buildStatement(clientId);

    // 5. Verify statement properties
    expect(statement.openingBalanceMinor, 0);
    expect(statement.totalDebitMinor, 10000);
    expect(statement.totalCreditMinor, 6000);
    expect(statement.closingBalanceMinor, 4000);
    expect(statement.entries.length, 2);

    // Verify entries details
    final entry1 = statement.entries[0]; // The invoice
    expect(entry1.type, StatementEntryType.invoice);
    expect(entry1.debitMinor, 10000);
    expect(entry1.creditMinor, 0);
    expect(entry1.runningBalanceMinor, 10000);

    final entry2 = statement.entries[1]; // The payment
    expect(entry2.type, StatementEntryType.payment);
    expect(entry2.debitMinor, 0);
    expect(entry2.creditMinor, 6000);
    expect(entry2.runningBalanceMinor, 4000);

    // 6. Verify that closingBalanceMinor matches clientAccountBalanceMinor
    final repoBalance = await paymentRepo.clientAccountBalanceMinor(clientId);
    expect(statement.closingBalanceMinor, repoBalance);
  });
}
