import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:fawatir/main.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:fawatir/app/router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fawatir/data/db/tables.dart';
import 'package:fawatir/features/invoices/data/invoice_repository.dart';
import 'package:fawatir/features/invoices/presentation/invoice_form_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    goRouter.go('/dashboard');
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MyApp(router: createRouter(initialLocation: '/dashboard')),
    );
  }

  Future<void> pumpAndIdle(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Invoice creation form and dynamic totals test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Insert an active client in database
    final clientId = await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('شريك النجاح'),
        isActive: Value(true),
        accountCurrency: Value('USD'),
      ),
    );

    // 2. Pump main app
    await tester.pumpWidget(createTestWidget());
    await tester.pump(const Duration(milliseconds: 500));

    // 3. Navigate to Invoices branch using the bottom navigation icon
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await pumpAndIdle(tester);

    // 4. Verify invoices placeholder list screen is visible
    expect(find.text('لا توجد فواتير بعد'), findsOneWidget);

    // 5. Tap FAB to open new invoice form
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await pumpAndIdle(tester);

    // 6. Verify invoice form screen is open
    expect(find.text('إنشاء فاتورة جديدة'), findsAtLeastNWidgets(1));

    // 7. Open client dropdown and select the client
    final dropdownFinder = find.widgetWithText(DropdownButtonFormField<Client>, 'اختر العميل *');
    expect(dropdownFinder, findsOneWidget);
    await tester.tap(dropdownFinder);
    await pumpAndIdle(tester);

    // Tap the dropdown menu item (shows client name)
    await tester.tap(find.textContaining('شريك النجاح').last);
    await pumpAndIdle(tester);

    // 8. Add a second line item row
    final addRowButton = find.text('إضافة بند');
    expect(addRowButton, findsOneWidget);
    await tester.tap(addRowButton);
    await pumpAndIdle(tester);

    // Verify there are 2 description fields
    final descField1 = find.widgetWithText(TextFormField, 'وصف البند *').at(0);
    final descField2 = find.widgetWithText(TextFormField, 'وصف البند *').at(1);
    
    // Fill first row: desc 'بند 1', qty '2', price '10.5' (10.5 * 100 = 1050 minor) -> total 21.00 USD
    await tester.enterText(descField1, 'تصميم واجهة');
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية *').at(0), '2');
    await tester.enterText(find.widgetWithText(TextFormField, 'سعر الوحدة *').at(0), '10.5');
    await tester.pump();

    // Fill second row: desc 'بند 2', qty '1', price '5' -> total 5.00 USD
    await tester.enterText(descField2, 'برمجة السيرفر');
    await tester.enterText(find.widgetWithText(TextFormField, 'الكمية *').at(1), '1');
    await tester.enterText(find.widgetWithText(TextFormField, 'سعر الوحدة *').at(1), '5');
    await tester.pump();

    // Scroll down to make sure the grand total card is visible and built
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await pumpAndIdle(tester);

    // Verify grand total is 26.00 USD (21.00 + 5.00)
    expect(find.text('26.00 \$'), findsWidgets);

    // 9. Tap save draft button in bottom action bar
    final saveDraftButton = find.text('حفظ كمسودة');
    expect(saveDraftButton, findsOneWidget);
    await tester.tap(saveDraftButton);
    await pumpAndIdle(tester);

    // 10. Verify we popped back to invoices screen and the invoice card is visible
    expect(find.text('INV-2026-0001'), findsOneWidget);
    expect(find.text('شريك النجاح'), findsOneWidget);

    // 11. Verify invoice was inserted into the database with total 2600 minor and status draft
    final invoices = await db.select(db.invoices).get();
    expect(invoices.length, 1);
    expect(invoices[0].clientId, clientId);
    expect(invoices[0].totalMinor, 2600); // 26.00 * 100
    expect(invoices[0].currency, 'USD');
    expect(invoices[0].status, InvoiceStatus.draft);

    // 12. Verify line items were inserted
    final items = await db.select(db.invoiceItems).get();
    expect(items.length, 2);
    expect(items[0].description, 'تصميم واجهة');
    expect(items[0].lineTotalMinor, 2100);
    expect(items[1].description, 'برمجة السيرفر');
    expect(items[1].lineTotalMinor, 500);

    // 13. Verify Phase 2 features:
    // Filter chip counters
    expect(find.text('الكل (1)'), findsOneWidget);
    expect(find.text('مسودة (1)'), findsOneWidget);

    // Summary card
    expect(find.text('إجمالي الفواتير'), findsOneWidget);

    // Search field
    final searchField = find.byType(TextFormField).first;
    await tester.enterText(searchField, 'غير_موجود');
    await pumpAndIdle(tester);
    expect(find.text('لا توجد فواتير مطابقة'), findsOneWidget);

    // Clear search using the action button and verify card returns
    await tester.tap(find.text('مسح البحث'));
    await pumpAndIdle(tester);
    expect(find.text('INV-2026-0001'), findsOneWidget);

    // Clean up by disposing the widget tree
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('InvoiceRepository calculateTotals handles percentage and fixed discount and tax', () {
    // 100.00 subtotal, 10% discount -> 10.00 discount, net 90.00, 15% tax on 90.00 -> 13.50 tax, total 103.50
    final result1 = InvoiceRepository.calculateTotals(
      subtotalMinor: 10000,
      discountPercent: 10.0,
      taxPercent: 15.0,
    );
    expect(result1.subtotal, 10000);
    expect(result1.discount, 1000);
    expect(result1.tax, 1350);
    expect(result1.total, 10350);

    // Fixed discount test: 20.00 flat discount, 5% tax
    final result2 = InvoiceRepository.calculateTotals(
      subtotalMinor: 10000,
      discountMinor: 2000,
      taxPercent: 5.0,
    );
    expect(result2.subtotal, 10000);
    expect(result2.discount, 2000);
    expect(result2.tax, 400); // 5% of 8000 = 400
    expect(result2.total, 8400);

    // Over-discount clamp test: discount > subtotal
    final result3 = InvoiceRepository.calculateTotals(
      subtotalMinor: 5000,
      discountMinor: 7000,
    );
    expect(result3.subtotal, 5000);
    expect(result3.discount, 5000);
    expect(result3.tax, 0);
    expect(result3.total, 0);
  });

  testWidgets('Quick invoice initialClientId preselection test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final clientId = await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('عميل سريع'),
        isActive: Value(true),
        accountCurrency: Value('SAR'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: InvoiceFormScreen(initialClientId: clientId),
        ),
      ),
    );
    await pumpAndIdle(tester);

    // Verify client is preselected in the form
    expect(find.textContaining('عميل سريع'), findsOneWidget);
    // Verify invoice currency was automatically initialized to client's currency (SAR)
    expect(find.textContaining('SAR'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
