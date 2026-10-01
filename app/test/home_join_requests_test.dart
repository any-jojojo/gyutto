import 'package:gyutto/models/chat_safety_state.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/features/home/logged_in_home_screen.dart';
import 'package:gyutto/models/app_user.dart';
import 'package:gyutto/models/join_request.dart';

const requestA = JoinRequest(
  userId: 'child-a',
  displayName: 'はる',
  status: 'pending',
  requestedAt: null,
);
const requestB = JoinRequest(
  userId: 'child-b',
  displayName: 'そら',
  status: 'pending',
  requestedAt: null,
);
AppUser user(AppUserRole role) => AppUser(
  uid: 'parent',
  displayName: '親',
  email: null,
  familyId: 'family',
  role: role,
);

void main() {
  for (final role in [AppUserRole.parent, AppUserRole.familyAdmin]) {
    testWidgets('live requests and individual approval for $role', (
      tester,
    ) async {
      final requests = StreamController<List<JoinRequest>>();
      addTearDown(requests.close);
      final completed = Completer<void>();
      String? approvedId;
      await tester.pumpWidget(
        MaterialApp(
          home: LoggedInHomeScreen(
            userStream: Stream.value(user(role)),
            joinRequestsStream: requests.stream,
            approveJoinRequest: (familyId, userId) {
              expect(familyId, 'family');
              approvedId = userId;
              return completed.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      requests.add([]);
      await tester.pump();
      expect(find.text('こどもの参加申請を許可する'), findsNothing);
      requests.add([requestA, requestB]);
      await tester.pumpAndSettle();
      expect(find.text('こどもの参加申請を許可する'), findsNWidgets(2));
      await tester.tap(find.text('こどもの参加申請を許可する').first);
      await tester.pump();
      expect(approvedId, 'child-a');
      expect(find.text('こども参加申請を許可しました！'), findsNothing);
      // Firestore may remove the request before the callable response arrives.
      requests.add([requestB]);
      await tester.pump();
      completed.complete();
      await tester.pumpAndSettle();
      expect(find.text('こども参加申請を許可しました！'), findsOneWidget);
      expect(find.text('こどもの参加申請を許可する'), findsOneWidget);
      expect(find.textContaining('そらさん'), findsOneWidget);
      requests.add([]);
      await tester.pumpAndSettle();
      expect(find.text('こどもの参加申請を許可する'), findsNothing);
    });
  }
  testWidgets('child does not see approval actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoggedInHomeScreen(
          userStream: Stream.value(user(AppUserRole.child)),
          joinRequestsStream: Stream.value([requestA]),
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
    expect(find.text('こどもの参加申請を許可する'), findsNothing);
  });
}
