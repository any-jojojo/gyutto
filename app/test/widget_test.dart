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

  testWidgets('opens login screen from home action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GyuttoApp());

    await tester.tap(find.text(AppStrings.createFamily));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.loginTitle), findsWidgets);
    expect(find.text(AppStrings.loginAction), findsOneWidget);
  });

  testWidgets('switches login screen to sign up mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const GyuttoApp());

    await tester.tap(find.text(AppStrings.createFamily));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.signUpTab));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.signUpTitle), findsWidgets);
    expect(find.text(AppStrings.signUpAction), findsOneWidget);
  });
}
