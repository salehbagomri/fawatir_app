import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/products/data/product_repository.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';

void main() {
  late AppDatabase db;
  late ProductRepository productRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    productRepo = ProductRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Products Catalog CRUD', () {
    test('Create, retrieve, update and delete products', () async {
      // 1. Create products
      final p1Id = await productRepo.createProduct(
        const ProductsCompanion(
          name: Value('باقة نت شهرية'),
          code: Value('NET-01'),
          defaultPriceMinor: Value(6500), // $65.00
          defaultCostMinor: Value(5500),  // $55.00
          description: Value('سداد باقة إنترنت عبر البطاقة'),
        ),
      );

      final p2Id = await productRepo.createProduct(
        const ProductsCompanion(
          name: Value('شحن رصيد'),
          code: Value('TOPUP'),
          defaultPriceMinor: Value(1200),
          defaultCostMinor: Value(1000),
        ),
      );

      expect(p1Id, isPositive);
      expect(p2Id, isPositive);

      // 2. Fetch by ID
      final p1 = await productRepo.getProductById(p1Id);
      expect(p1, isNotNull);
      expect(p1!.name, 'باقة نت شهرية');
      expect(p1.defaultPriceMinor, 6500);
      expect(p1.defaultCostMinor, 5500);

      // 3. Update product
      await productRepo.updateProduct(
        p1Id,
        const ProductsCompanion(
          name: Value('باقة نت سوبر'),
          defaultPriceMinor: Value(7000),
        ),
      );
      final updatedP1 = await productRepo.getProductById(p1Id);
      expect(updatedP1!.name, 'باقة نت سوبر');
      expect(updatedP1.defaultPriceMinor, 7000);

      // 4. Delete product
      await productRepo.deleteProduct(p2Id);
      final activeProducts = await productRepo.getActiveProducts();
      expect(activeProducts.length, 1);
      expect(activeProducts.first.id, p1Id);
    });
  });

  group('Invoice Profit & Fees Analytics', () {
    test('calculateInvoiceProfit correctly accounts for unit cost and bank transaction fees', () {
      // Scenario from User:
      // Client package price: $65.00 (selling price = 6500 minor)
      // Unit cost: $55.00 (cost price = 5500 minor)
      // Bank transfer fee: $1.50 (fees = 150 minor)
      // Expected net profit: $65.00 - $55.00 - $1.50 = $8.50 (850 minor)
      // Expected margin: (8.50 / 65.00) * 100 = 13.0769%

      final invoice = Invoice(
        id: 1,
        number: 'INV-2026-0001',
        clientId: 1,
        issueDate: DateTime.now(),
        currency: 'USD',
        fxRateToAccount: 1.0,
        discountPercent: 0,
        discountMinor: 0,
        taxPercent: 0,
        taxMinor: 0,
        totalMinor: 6500,
        transactionFeesMinor: 150, // 1.50$
        status: InvoiceStatus.sent,
        createdAt: DateTime.now(),
      );

      final items = [
        const InvoiceItem(
          id: 1,
          invoiceId: 1,
          description: 'باقة نت شهرية',
          quantity: 1,
          unitPriceMinor: 6500,
          costPriceMinor: 5500, // 55.00$
          lineTotalMinor: 6500,
        ),
      ];

      final profit = calculateInvoiceProfit(invoice, items);

      expect(profit.totalRevenueMinor, 6500);
      expect(profit.totalCostMinor, 5500);
      expect(profit.transactionFeesMinor, 150);
      expect(profit.netProfitMinor, 850); // $8.50
      expect(profit.profitMarginPercent, closeTo(13.07, 0.02));
    });

    test('calculateInvoiceProfit handles multiple items with varying quantities', () {
      final invoice = Invoice(
        id: 2,
        number: 'INV-2026-0002',
        clientId: 1,
        issueDate: DateTime.now(),
        currency: 'USD',
        fxRateToAccount: 1.0,
        discountPercent: 0,
        discountMinor: 0,
        taxPercent: 0,
        taxMinor: 0,
        totalMinor: 10000,
        transactionFeesMinor: 200,
        status: InvoiceStatus.paid,
        createdAt: DateTime.now(),
      );

      final items = [
        const InvoiceItem(
          id: 1,
          invoiceId: 2,
          description: 'سيرفر',
          quantity: 2,
          unitPriceMinor: 3000, // 2 * 3000 = 6000
          costPriceMinor: 2000, // 2 * 2000 = 4000 cost
          lineTotalMinor: 6000,
        ),
        const InvoiceItem(
          id: 2,
          invoiceId: 2,
          description: 'صيانة',
          quantity: 1,
          unitPriceMinor: 4000, // 1 * 4000 = 4000
          costPriceMinor: 2500, // 1 * 2500 = 2500 cost
          lineTotalMinor: 4000,
        ),
      ];

      final profit = calculateInvoiceProfit(invoice, items);

      expect(profit.totalRevenueMinor, 10000);
      expect(profit.totalCostMinor, 6500); // 4000 + 2500
      expect(profit.transactionFeesMinor, 200);
      expect(profit.netProfitMinor, 3300); // 10000 - 6500 - 200
      expect(profit.profitMarginPercent, 33.0);
    });
  });
}
