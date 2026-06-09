import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fawatir/main.dart';

void main() {
  testWidgets('App navigation smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Pump and settle to let the router initialize the first page.
    await tester.pumpAndSettle();

    // Verify that the initial dashboard screen is displayed.
    expect(find.text('لوحة المعلومات'), findsAtLeast(1));

    // Tap the Clients tab and trigger a frame.
    await tester.tap(find.text('العملاء'));
    await tester.pumpAndSettle();

    // Verify that the clients screen is displayed.
    expect(find.text('العملاء'), findsAtLeast(1));
  });
}
