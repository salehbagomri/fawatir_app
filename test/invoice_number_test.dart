import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';

void main() {
  late AppDatabase db;
  late InvoiceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = InvoiceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('nextInvoiceNumber generates sequential and formatted invoice numbers', () async {
    // 1. Insert a company with prefix 'INV-' and counter 0
    await db.into(db.companies).insert(
      const CompaniesCompanion(
        id: Value(1),
        name: Value('شركة تجريبية'),
        defaultCurrency: Value('SAR'),
        invoicePrefix: Value('INV-'),
        invoiceCounter: Value(0),
      ),
    );

    // 2. Fetch current year to build expected format
    final currentYear = DateTime.now().year;

    // 3. Call nextInvoiceNumber first time
    final num1 = await repo.nextInvoiceNumber();
    expect(num1, 'INV-$currentYear-0001');

    // 4. Call nextInvoiceNumber second time
    final num2 = await repo.nextInvoiceNumber();
    expect(num2, 'INV-$currentYear-0002');

    // 5. Verify the counter value in database is 2
    final company = await (db.select(db.companies)..where((tbl) => tbl.id.equals(1))).getSingle();
    expect(company.invoiceCounter, 2);
  });

  test('nextInvoiceNumber inserts default company and increments if company not present', () async {
    final currentYear = DateTime.now().year;

    // Call nextInvoiceNumber when no company exists
    final num1 = await repo.nextInvoiceNumber();
    expect(num1, 'INV-$currentYear-0001');

    // Verify company id 1 has been automatically created
    final company = await (db.select(db.companies)..where((tbl) => tbl.id.equals(1))).getSingle();
    expect(company.invoiceCounter, 1);
    expect(company.invoicePrefix, 'INV-');
  });
}
