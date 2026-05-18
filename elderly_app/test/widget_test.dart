import 'package:flutter_test/flutter_test.dart';
import 'package:elderly_app/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ElderlyApp());
    expect(find.text('银发陪驾'), findsOneWidget);
  });
}