import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/app.dart';
import 'package:gyutto/core/constants/app_strings.dart';
import 'package:gyutto/core/router/app_router.dart';
import 'package:gyutto/core/router/app_routes.dart';
import 'package:gyutto/features/home/logged_in_home_screen.dart';
import 'package:gyutto/models/app_user.dart';

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
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(userStream: Stream.value(_familyAdminUser)),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.loggedInHomeTitle), findsOneWidget);
    expect(find.text(AppStrings.loggedInHomeDescription), findsOneWidget);
    expect(find.text(AppStrings.createFamilyPageTitle), findsNothing);
    expect(find.text(AppStrings.inviteParentAccount), findsOneWidget);
    expect(find.text(AppStrings.inviteChildAccount), findsOneWidget);
  });

  testWidgets('opens create family screen before family creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(userStream: Stream.value(_userWithoutFamily)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.createFamilyPageTitle));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.familyName), findsOneWidget);
    expect(find.text(AppStrings.adminDisplayName), findsOneWidget);
  });

  testWidgets('hides invite actions before family creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(userStream: Stream.value(_userWithoutFamily)),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.createFamilyPageTitle), findsOneWidget);
    expect(find.text(AppStrings.joinFamily), findsOneWidget);
    expect(find.text(AppStrings.inviteParentAccount), findsNothing);
    expect(find.text(AppStrings.inviteChildAccount), findsNothing);
  });

  testWidgets('opens parent invite join screen without family', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(userStream: Stream.value(_userWithoutFamily)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.joinFamily));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.joinParentInvitePageTitle), findsWidgets);
    expect(find.text(AppStrings.parentInviteCode), findsOneWidget);
  });

  testWidgets('opens invite screens from logged in home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(userStream: Stream.value(_familyAdminUser)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.inviteParentAccount));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.inviteParentPageTitle), findsWidgets);

    Navigator.of(
      tester.element(find.text(AppStrings.inviteParentPageTitle).first),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.inviteChildAccount));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.inviteChildPageTitle), findsWidgets);
    expect(find.text(AppStrings.createChildQrInvite), findsOneWidget);
  });

  testWidgets('shows only child invite action for parent user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(userStream: Stream.value(_parentUser)),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.createFamilyPageTitle), findsNothing);
    expect(find.text(AppStrings.inviteParentAccount), findsNothing);
    expect(find.text(AppStrings.inviteChildAccount), findsOneWidget);
  });

  testWidgets('opens parent invite screen route', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.inviteParent,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    expect(find.text(AppStrings.inviteParentPageTitle), findsWidgets);
    expect(find.text(AppStrings.createParentInviteCode), findsOneWidget);
  });

  testWidgets('opens child invite join screen route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: '${AppRoutes.joinChildInvite}?token=test-token',
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    expect(find.text(AppStrings.joinChildInvitePageTitle), findsWidgets);
    expect(find.text(AppStrings.childInviteConfirmMessage), findsOneWidget);
    expect(find.text(AppStrings.childDisplayName), findsOneWidget);
  });
}

const _familyAdminUser = AppUser(
  uid: 'admin-user',
  displayName: '管理者',
  email: 'admin@example.com',
  familyId: 'family-1',
  role: AppUserRole.familyAdmin,
);

const _userWithoutFamily = AppUser(
  uid: 'new-user',
  displayName: null,
  email: 'new@example.com',
  familyId: null,
  role: AppUserRole.familyAdmin,
);

const _parentUser = AppUser(
  uid: 'parent-user',
  displayName: '親',
  email: 'parent@example.com',
  familyId: 'family-1',
  role: AppUserRole.parent,
);
