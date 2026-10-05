import 'package:gyutto/models/chat_safety_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/features/settings/settings_screen.dart';
import 'package:gyutto/features/home/logged_in_home_screen.dart';
import 'package:gyutto/models/app_user.dart';
import 'package:gyutto/models/chat_message.dart';

void main() {
  testWidgets('opens direct privacy policy URL', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          openPage: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('プライバシーポリシー'));
    await tester.pumpAndSettle();
    expect(opened.toString(), privacyPolicyUrl);
  });
  for (final throwsError in [false, true]) {
    testWidgets('policy URL remains available on launch failure $throwsError', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            openPage: (_) async {
              if (throwsError) throw StateError('No browser');
              return false;
            },
          ),
        ),
      );
      await tester.tap(find.text('プライバシーポリシー'));
      await tester.pumpAndSettle();
      expect(find.text('ポリシーを開けませんでした'), findsOneWidget);
      expect(find.text(privacyPolicyUrl), findsOneWidget);
    });
  }
  testWidgets('opens only the deletion page when requested', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          openPage: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );
    expect(opened, isNull);
    await tester.tap(find.text('アカウント削除を申請'));
    await tester.pumpAndSettle();
    expect(opened.toString(), accountDeletionUrl);
    expect(find.text('申請ページを開けませんでした'), findsNothing);
  });
  for (final throwsError in [false, true]) {
    testWidgets('shows contact fallback when browser fails ($throwsError)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            openPage: (_) async {
              if (throwsError) throw Exception('No browser');
              return false;
            },
          ),
        ),
      );
      await tester.tap(find.text('アカウント削除を申請'));
      await tester.pumpAndSettle();
      expect(find.text('申請ページを開けませんでした'), findsOneWidget);
      expect(find.text(accountDeletionUrl), findsOneWidget);
      expect(find.text(accountDeletionEmail), findsWidgets);
    });
  }
  for (final role in [AppUserRole.familyAdmin, AppUserRole.child]) {
    testWidgets('settings is reachable for $role', (tester) async {
      final user = AppUser(
        uid: 'test-user',
        displayName: 'テスト',
        email: null,
        familyId: 'family',
        role: role,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LoggedInHomeScreen(
            joinRequestsStream: Stream.value(const []),
            userStream: Stream.value(user),
            chatSafetyStateStream: Stream.value(
              const ChatSafetyState(
                role: 'child',
                active: true,
                safetyAccepted: true,
                permission: 'allowed',
                serverVerified: true,
              ),
            ),
            chatMessagesStream: Stream<List<ChatMessage>>.value([]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('設定'));
      await tester.pumpAndSettle();
      expect(find.text('アカウント削除を申請'), findsOneWidget);
    });
  }
}
