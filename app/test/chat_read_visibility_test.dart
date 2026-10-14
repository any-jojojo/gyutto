import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/features/chat/presentation/family_chat_screen.dart';
import 'package:gyutto/models/app_user.dart';
import 'package:gyutto/models/chat_message.dart';
import 'package:gyutto/models/chat_safety_state.dart';
import 'package:gyutto/repositories/chat_repository.dart';
import 'package:gyutto/services/chat_notification_service.dart';

class _Chat extends Fake implements ChatRepository {
  final List<String> read = [];
  final List<String> sent = [];
  @override
  Future<void> sendMessage({
    required String familyId,
    required String senderUserId,
    required String senderDisplayName,
    required String text,
  }) async {
    sent.add(text);
  }

  @override
  Future<void> markAsRead({
    required String familyId,
    required String messageId,
    required String userId,
    required String displayName,
  }) async {
    read.add(messageId);
  }
}

void main() {
  testWidgets('release chat sends without the undeployed moderation backend', (
    tester,
  ) async {
    const user = AppUser(
      uid: 'parent',
      displayName: '親',
      email: null,
      familyId: 'f',
      role: AppUserRole.parent,
    );
    final chat = _Chat();
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyChatScreen(
          user: user,
          chatRepository: chat,
          messagesStream: Stream.value(const []),
          safetyStateStream: Stream.value(
            const ChatSafetyState(
              role: 'parent',
              active: true,
              safetyAccepted: true,
              adultConfirmed: true,
              serverVerified: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('ユーザーを通報'), findsNothing);
    await tester.enterText(find.byType(TextField), '通知の確認');
    await tester.tap(find.byTooltip('送信'));
    await tester.pumpAndSettle();
    expect(chat.sent, ['通知の確認']);
    expect(find.text('投稿前に確認してください'), findsNothing);
  });
  testWidgets('background and covered chat do not mark new messages read', (
    tester,
  ) async {
    const user = AppUser(
      uid: 'child',
      displayName: '子ども',
      email: null,
      familyId: 'f',
      role: AppUserRole.child,
    );
    final chat = _Chat();
    final messages = StreamController<List<ChatMessage>>();
    addTearDown(messages.close);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [chatRouteObserver],
        home: FamilyChatScreen(
          user: user,
          chatRepository: chat,
          messagesStream: messages.stream,
          safetyStateStream: Stream.value(
            const ChatSafetyState(
              role: 'child',
              active: true,
              safetyAccepted: true,
              permission: 'allowed',
              serverVerified: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    messages.add(const []);
    await tester.pumpAndSettle();
    ChatMessage message(String id) => ChatMessage(
      id: id,
      senderUserId: 'parent',
      senderDisplayName: '親',
      text: 'こんにちは',
      readBy: const {},
      createdAt: DateTime.now(),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    messages.add([message('background')]);
    await tester.pumpAndSettle();
    expect(chat.read, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(chat.read, ['background']);
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('別の画面')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    messages.add([message('covered')]);
    await tester.pumpAndSettle();
    expect(chat.read, ['background']);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(chat.read, ['background', 'covered']);
    await tester.pumpWidget(const SizedBox());
  });
}
