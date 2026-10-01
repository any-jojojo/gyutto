import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/features/safety/chat_safety_gate.dart';
import 'package:gyutto/models/app_user.dart';
import 'package:gyutto/models/chat_safety_state.dart';

const user = AppUser(
  uid: 'child',
  displayName: '子ども',
  email: null,
  familyId: 'f',
  role: AppUserRole.child,
);

void main() {
  testWidgets('requires safety and guardian permission; pause removes chat', (
    tester,
  ) async {
    final states = StreamController<ChatSafetyState>();
    addTearDown(states.close);
    var acknowledgements = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatSafetyGate(
          user: user,
          stateStream: states.stream,
          onAcknowledge: () async {
            acknowledgements++;
          },
          builder: (_) => const Scaffold(body: Text('CHAT CONTENT')),
        ),
      ),
    );
    states.add(
      const ChatSafetyState(role: 'child', active: true, serverVerified: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('チャットをはじめる前に'), findsOneWidget);
    expect(find.text('CHAT CONTENT'), findsNothing);
    await tester.tap(find.text('読んで確認しました'));
    await tester.pumpAndSettle();
    expect(acknowledgements, 1);
    expect(find.text('CHAT CONTENT'), findsNothing);
    states.add(
      const ChatSafetyState(
        role: 'child',
        active: true,
        serverVerified: true,
        safetyAccepted: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('保護者の利用許可を待っています'), findsOneWidget);
    states.add(
      const ChatSafetyState(
        role: 'child',
        active: true,
        serverVerified: true,
        safetyAccepted: true,
        permission: 'allowed',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHAT CONTENT'), findsOneWidget);
    states.add(
      const ChatSafetyState(
        role: 'child',
        active: true,
        serverVerified: true,
        safetyAccepted: true,
        permission: 'paused',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHAT CONTENT'), findsNothing);
    expect(find.textContaining('お休み中'), findsOneWidget);
  });
  testWidgets('cache alone cannot unlock chat', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatSafetyGate(
          user: user,
          stateStream: Stream.value(
            const ChatSafetyState(
              role: 'child',
              active: true,
              safetyAccepted: true,
              permission: 'allowed',
            ),
          ),
          builder: (_) => const Text('CHAT CONTENT'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CHAT CONTENT'), findsNothing);
  });
  testWidgets('adult confirmation needs declaration and passes password', (
    tester,
  ) async {
    String? password;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdultConfirmationForm(
            busy: false,
            onConfirm: (value) async {
              password = value;
            },
          ),
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'example-password');
    await tester.tap(find.text('保護者として確認する'));
    await tester.pump();
    expect(password, 'example-password');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
