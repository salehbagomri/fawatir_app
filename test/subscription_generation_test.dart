import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:drift/drift.dart' hide isNotNull;

void main() {
  late AppDatabase db;
  late InvoiceRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = InvoiceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('generateMonthlyInvoices creates draft invoice for active subscription without duplicates', () async {
    // 1. Insert Client
    final clientId = await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('عميل اشتراكات'),
        accountCurrency: Value('USD'),
        isActive: Value(true),
      ),
    );

    // 2. Insert active subscription (startDate in the past, e.g. 2026-05-01, unitPriceMinor 5000, currency USD)
    final subId = await db.into(db.subscriptions).insert(
      SubscriptionsCompanion(
        clientId: Value(clientId),
        title: const Value('الاشتراك الشهري المميز'),
        unitPriceMinor: const Value(5000),
        currency: const Value('USD'),
        billingDayOfMonth: const Value(10),
        startDate: Value(DateTime(2026, 5, 1)),
        isActive: const Value(true),
      ),
    );

    // 3. Generate invoices for June 2026
    final targetMonth = DateTime(2026, 6, 15);
    final createdIds = await repository.generateMonthlyInvoices(forMonth: targetMonth);

    expect(createdIds.length, 1);

    // Verify invoice details
    final invoice = await repository.getInvoice(createdIds[0]);
    expect(invoice, isNotNull);
    expect(invoice!.clientId, clientId);
    expect(invoice.status, InvoiceStatus.draft);
    expect(invoice.currency, 'USD');
    expect(invoice.subscriptionId, subId);
    expect(invoice.totalMinor, 5000);

    // Verify items details
    final items = await repository.getItems(createdIds[0]);
    expect(items.length, 1);
    expect(items[0].description, 'الاشتراك الشهري المميز — 6/2026');
    expect(items[0].quantity, 1.0);
    expect(items[0].unitPriceMinor, 5000);
    expect(items[0].lineTotalMinor, 5000);

    // 4. Run second generation for same month -> should yield 0 new invoices
    final secondCreatedIds = await repository.generateMonthlyInvoices(forMonth: targetMonth);
    expect(secondCreatedIds.length, 0);
  });
}
