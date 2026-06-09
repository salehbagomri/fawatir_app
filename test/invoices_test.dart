import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:fawatir/main.dart';
import 'package:fawatir/data/db/database.dart';
import 'package:drift/drift.dart' hide Column;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const MyApp(),
    );
  }

  Future<void> pumpAndIdle(WidgetTester tester) async {
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Invoice creation form and dynamic totals test', (WidgetTester tester) async {
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
    await tester.tap(find.byIcon(Icons.receipt_long));
    await pumpAndIdle(tester);

    // 4. Verify invoices placeholder list screen is visible
    expect(find.text('لا توجد فواتير بعد'), findsOneWidget);

    // 5. Tap FAB to open new invoice form
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // 6. Verify invoice form screen is open
    expect(find.text('إنشاء فاتورة جديدة'), findsOneWidget);

    // 7. Open client dropdown and select the client
    final dropdownFinder = find.widgetWithText(DropdownButtonFormField<Client>, 'اختر العميل *');
    expect(dropdownFinder, findsOneWidget);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Tap the dropdown menu item (shows client name)
    await tester.tap(find.textContaining('شريك النجاح').last);
    await tester.pumpAndSettle();

    // 8. Add a second line item row
    final addRowButton = find.text('إضافة بند');
    expect(addRowButton, findsOneWidget);
    await tester.tap(addRowButton);
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();



    // Verify grand total is 26.00 USD (21.00 + 5.00)
    expect(find.text('26.00 \$'), findsWidgets);

    // 9. Tap save button (the check icon in app bar)
    final saveButton = find.byIcon(Icons.check);
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // 10. Verify we popped back to invoices screen and the invoice card is visible
    expect(find.text('INV-2026-0001'), findsOneWidget);
    expect(find.text('شريك النجاح'), findsOneWidget);

    // 11. Verify invoice was inserted into the database with total 2600 minor
    final invoices = await db.select(db.invoices).get();
    expect(invoices.length, 1);
    expect(invoices[0].clientId, clientId);
    expect(invoices[0].totalMinor, 2600); // 26.00 * 100
    expect(invoices[0].currency, 'USD');

    // 12. Verify line items were inserted
    final items = await db.select(db.invoiceItems).get();
    expect(items.length, 2);
    expect(items[0].description, 'تصميم واجهة');
    expect(items[0].lineTotalMinor, 2100);
    expect(items[1].description, 'برمجة السيرفر');
    expect(items[1].lineTotalMinor, 500);

    // Clean up by disposing the widget tree
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
