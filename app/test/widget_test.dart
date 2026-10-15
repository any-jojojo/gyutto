import 'package:gyutto/models/chat_safety_state.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/app.dart';
import 'package:gyutto/core/constants/app_strings.dart';
import 'package:gyutto/core/router/app_router.dart';
import 'package:gyutto/core/router/app_routes.dart';
import 'package:gyutto/features/home/logged_in_home_screen.dart';
import 'package:gyutto/models/app_user.dart';
import 'package:gyutto/models/chat_message.dart';

void main() {
  testWidgets('parent can access child join requests', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_parentUser),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('子アカウントの参加申請'), 200);
    expect(find.text('子アカウントの参加申請'), findsOneWidget);
  });

  testWidgets('pending child cannot chat until approval arrives', (
    tester,
  ) async {
    final users = StreamController<AppUser?>();
    addTearDown(users.close);
    await tester.pumpWidget(
      MaterialApp(
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: users.stream,
          chatSafetyStateStream: Stream.value(
            const ChatSafetyState(
              role: 'child',
              active: true,
              safetyAccepted: true,
              permission: 'allowed',
              serverVerified: true,
            ),
          ),
          chatMessagesStream: Stream.value(const []),
        ),
      ),
    );
    users.add(
      const AppUser(
        uid: 'child-user',
        displayName: 'こども',
        email: null,
        familyId: null,
        role: AppUserRole.unknown,
        pendingFamilyId: 'family-1',
        pendingJoinRequestStatus: 'pending',
      ),
    );
    await tester.pump();
    expect(find.text('子アカウントの参加申請は承認待ちです。'), findsOneWidget);
    expect(find.text('メッセージを入力'), findsNothing);
    expect(find.text('子アカウントの参加申請'), findsNothing);
    users.add(_childUser);
    await tester.pumpAndSettle();
    expect(find.text('メッセージを入力'), findsOneWidget);
    expect(find.text('子アカウントの参加申請は承認待ちです。'), findsNothing);
  });

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
    await tester.scrollUntilVisible(
      find.text(AppStrings.loginAction),
      150,
      scrollable: find.byType(Scrollable).first,
    );
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
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_familyAdminUser),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.loggedInHomeTitle), findsOneWidget);
    expect(find.text(AppStrings.loggedInHomeDescription), findsOneWidget);
    expect(find.text(AppStrings.createFamilyPageTitle), findsNothing);
    expect(find.text(AppStrings.familyChat), findsOneWidget);
    expect(find.text(AppStrings.inviteParentAccount), findsOneWidget);
    expect(find.text(AppStrings.inviteChildAccount), findsOneWidget);
  });

  testWidgets('opens create family screen before family creation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_userWithoutFamily),
        ),
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
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_userWithoutFamily),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.createFamilyPageTitle), findsOneWidget);
    expect(find.text(AppStrings.joinFamily), findsOneWidget);
    expect(find.text(AppStrings.familyChat), findsNothing);
    expect(find.text(AppStrings.inviteParentAccount), findsNothing);
    expect(find.text(AppStrings.inviteChildAccount), findsNothing);
  });

  testWidgets('opens parent invite join screen without family', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_userWithoutFamily),
        ),
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
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_familyAdminUser),
        ),
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
    expect(find.text(AppStrings.createChildQrInvite), findsNothing);
    expect(find.text('もう一度試す'), findsOneWidget);
  });

  testWidgets('shows only child invite action for parent user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_parentUser),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.createFamilyPageTitle), findsNothing);
    expect(find.text(AppStrings.inviteParentAccount), findsNothing);
    expect(find.text(AppStrings.familyChat), findsOneWidget);
    expect(find.text(AppStrings.inviteChildAccount), findsOneWidget);
  });

  testWidgets('opens family chat from parent home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_parentUser),
          chatSafetyStateStream: Stream.value(
            const ChatSafetyState(
              role: 'child',
              active: true,
              safetyAccepted: true,
              permission: 'allowed',
              serverVerified: true,
            ),
          ),
          chatMessagesStream: Stream.value(const []),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(AppStrings.familyChat));
    await tester.pumpAndSettle();

    expect(find.text('家族みんな'), findsOneWidget);
    expect(find.text('メッセージを入力'), findsOneWidget);
    expect(find.byTooltip('送信'), findsOneWidget);
  });

  testWidgets('shows read receipt on a message read by a family member', (
    WidgetTester tester,
  ) async {
    final message = ChatMessage(
      id: 'message-1',
      senderUserId: _parentUser.uid,
      senderDisplayName: _parentUser.displayName!,
      text: 'おかえり',
      readBy: {
        _parentUser.uid: const ReadReceipt(displayName: '親', readAt: null),
        _childUser.uid: const ReadReceipt(displayName: 'こども', readAt: null),
      },
      createdAt: DateTime(2026, 9, 3, 15, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_parentUser),
          chatSafetyStateStream: Stream.value(
            const ChatSafetyState(
              role: 'child',
              active: true,
              safetyAccepted: true,
              permission: 'allowed',
              serverVerified: true,
            ),
          ),
          chatMessagesStream: Stream.value([message]),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(AppStrings.familyChat));
    await tester.pumpAndSettle();

    expect(find.text('おかえり'), findsOneWidget);
    expect(find.text('こども既読'), findsOneWidget);
  });

  testWidgets('shows family chat instead of invite actions for child user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoggedInHomeScreen(
          joinRequestsStream: Stream.value(const []),
          userStream: Stream.value(_childUser),
          chatSafetyStateStream: Stream.value(
            const ChatSafetyState(
              role: 'child',
              active: true,
              safetyAccepted: true,
              permission: 'allowed',
              serverVerified: true,
            ),
          ),
          chatMessagesStream: Stream.value(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('家族みんな'), findsOneWidget);
    expect(find.text('メッセージを入力'), findsOneWidget);
    expect(find.byTooltip('送信'), findsOneWidget);
    expect(find.text(AppStrings.inviteParentAccount), findsNothing);
    expect(find.text(AppStrings.inviteChildAccount), findsNothing);
  });

  testWidgets('opens parent invite screen route', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
      MaterialApp(
        initialRoute:
            '${AppRoutes.joinChildInvite}?token=test-token&familyName=${Uri.encodeComponent('なかよし家族')}',
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    expect(find.text(AppStrings.joinChildInvitePageTitle), findsWidgets);
    expect(find.text('なかよし家族に参加しますか？'), findsOneWidget);
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

const _childUser = AppUser(
  uid: 'child-user',
  displayName: 'こども',
  email: null,
  familyId: 'family-1',
  role: AppUserRole.child,
);
