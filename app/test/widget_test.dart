import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/app.dart';
import 'package:gyutto/core/constants/app_strings.dart';

void main() {
  testWidgets('shows initial home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GyuttoApp());

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.homeTitle), findsOneWidget);
    expect(find.text(AppStrings.createFamily), findsOneWidget);
    expect(find.text(AppStrings.joinFamily), findsOneWidget);
  });
}
