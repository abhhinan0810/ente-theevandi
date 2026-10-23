import 'package:flutter_test/flutter_test.dart';
import 'package:passenger_app/main.dart';

void main() {
  testWidgets('EnteTheevandiApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EnteTheevandiApp());
    expect(find.byType(EnteTheevandiApp), findsOneWidget);
  });
}
