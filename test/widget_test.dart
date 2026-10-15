import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_android_browser/main.dart';

void main() {
  testWidgets('Browser app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BrowserApp());
    // Basic smoke test - app should build without crashing
    expect(find.byType(BrowserApp), findsOneWidget);
  });
}
