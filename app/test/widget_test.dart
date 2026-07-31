import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/app.dart';
import 'package:gyutto/core/constants/app_strings.dart';
import 'package:gyutto/core/router/app_router.dart';
import 'package:gyutto/core/router/app_routes.dart';

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

  testWidgets('shows logged in home route', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.loggedInHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    expect(find.text(AppStrings.loggedInHomeTitle), findsOneWidget);
    expect(find.text(AppStrings.loggedInHomeDescription), findsOneWidget);
    expect(find.text(AppStrings.createFamilyPageTitle), findsOneWidget);
    expect(find.text(AppStrings.inviteParentAccount), findsOneWidget);
    expect(find.text(AppStrings.inviteChildAccount), findsOneWidget);
  });

  testWidgets('opens create family screen from logged in home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.loggedInHome,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    await tester.tap(find.text(AppStrings.createFamilyPageTitle));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.familyName), findsOneWidget);
    expect(find.text(AppStrings.adminDisplayName), findsOneWidget);
  });
}
