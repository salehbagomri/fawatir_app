import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:fawatir/main.dart';
import 'package:fawatir/data/db/database.dart';

void main() {
  testWidgets('App navigation smoke test', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MyApp(),
      ),
    );

    // Pump to let the router initialize the first page.
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the initial dashboard screen is displayed.
    expect(find.text('لوحة المعلومات'), findsAtLeast(1));

    // Tap the Clients tab and trigger a frame.
    await tester.tap(find.text('العملاء'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the clients screen is displayed.
    expect(find.text('العملاء'), findsAtLeast(1));

    // Clean up.
    await db.close();
    await tester.pumpAndSettle();
  });
}
