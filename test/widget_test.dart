import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart';

void main() {
  testWidgets('renders hello text', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Hello, Flutter!'), findsOneWidget);
  });
}