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

  testWidgets('Clients Screen empty state and add client flow', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pump(const Duration(milliseconds: 500));

    // Navigate to Clients tab using icon (loading indicator is shown, use timed pump)
    await tester.tap(find.byIcon(Icons.people));
    await pumpAndIdle(tester);

    // Verify empty state message is shown
    expect(find.text('لا يوجد عملاء بعد'), findsOneWidget);

    // Tap on FAB to add client (no loaders on form, pumpAndSettle is safe)
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Verify Add Client Screen is open
    expect(find.text('إضافة عميل جديد'), findsOneWidget);

    // Enter name and phone
    await tester.enterText(find.widgetWithText(TextFormField, 'اسم العميل *'), 'أحمد محمد');
    await tester.enterText(find.widgetWithText(TextFormField, 'رقم الهاتف'), '777777777');
    await tester.pump();

    // Tap save button (pops back, use pumpAndSettle to let transition finish completely)
    final saveButton = find.byIcon(Icons.check);
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify we popped back to clients list and see the new client
    expect(find.widgetWithText(ListTile, 'أحمد محمد'), findsOneWidget);
    
    // Tap on client to view details
    await tester.tap(find.widgetWithText(ListTile, 'أحمد محمد'));
    await tester.pumpAndSettle();

    // Verify details screen shows client info
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.text('لا توجد مستحقات'), findsOneWidget); // Zero balance default
    
    // Expand details card to show phone number
    await tester.tap(find.text('المزيد من التفاصيل'));
    await tester.pumpAndSettle();

    expect(find.textContaining('777777777'), findsOneWidget);

    // Clean up by disposing the widget tree inside the test body first
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Clients Screen search and edit flow', (WidgetTester tester) async {
    // Pre-insert two clients
    await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('علي صالح'),
        phone: Value('711111111'),
        accountCurrency: Value('SAR'),
        isActive: Value(true),
      ),
    );
    await db.into(db.clients).insert(
      const ClientsCompanion(
        name: Value('خالد وليد'),
        phone: Value('733333333'),
        accountCurrency: Value('USD'),
        isActive: Value(false), // Inactive
      ),
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pump(const Duration(milliseconds: 500));

    // Navigate to Clients tab
    await tester.tap(find.byIcon(Icons.people));
    await pumpAndIdle(tester);

    // Verify both are listed
    expect(find.widgetWithText(ListTile, 'علي صالح'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'خالد وليد'), findsOneWidget);
    expect(find.text('غير نشط'), findsOneWidget); // خالد is inactive

    // Search for 'خالد'
    final searchField = find.widgetWithText(TextFormField, 'البحث عن عميل...');
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'خالد');
    await pumpAndIdle(tester);

    // Verify filtered results
    expect(find.widgetWithText(ListTile, 'خالد وليد'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'علي صالح'), findsNothing);

    // Tap on the filtered client to view details
    await tester.tap(find.text('خالد وليد'));
    await tester.pumpAndSettle();

    // Verify Client Detail Screen is open
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.text('لا توجد مستحقات'), findsOneWidget); // Zero balance

    // Expand details card to show phone number
    await tester.tap(find.text('المزيد من التفاصيل'));
    await tester.pumpAndSettle();

    expect(find.textContaining('733333333'), findsOneWidget);

    // Tap edit button to open form
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    // Verify Edit Client Screen is open and initial values are pre-filled
    expect(find.text('تعديل بيانات العميل'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'اسم العميل *'), findsOneWidget);

    // Update phone number
    await tester.enterText(find.widgetWithText(TextFormField, 'رقم الهاتف'), '733333334');
    await tester.pump();

    // Tap save (pops back to details screen, which redirects or pops to clients)
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // Verify we are back to clients screen and update is visible
    // We clear search to see both
    await tester.tap(find.byIcon(Icons.clear));
    await pumpAndIdle(tester);

    expect(find.widgetWithText(ListTile, 'خالد وليد'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.textContaining('733333334'),
      ),
      findsOneWidget,
    );

    // Clean up by disposing the widget tree inside the test body first
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
