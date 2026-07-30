import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/app.dart';

void main() {
  testWidgets('shows initial home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GyuttoApp());

    expect(find.text('ぎゅっと'), findsOneWidget);
    expect(find.text('家族のチャットをはじめましょう'), findsOneWidget);
  });
}
