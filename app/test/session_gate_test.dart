import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/app.dart';
import 'package:gyutto/core/constants/app_strings.dart';
import 'package:gyutto/features/auth/presentation/session_gate.dart';
import 'package:gyutto/models/app_user.dart';
import 'package:gyutto/repositories/auth_repository.dart';

const user = AppUser(
  uid: 'parent',
  displayName: '親',
  email: 'parent@example.com',
  familyId: null,
  role: AppUserRole.unknown,
);

class _Auth extends Fake implements AuthRepository {
  int attempts = 0;
  @override
  Stream<AppUser?> authStateChanges() {
    attempts++;
    return attempts == 1
        ? Stream.error(StateError('temporary'))
        : Stream.value(user);
  }
}

Widget _gate(Stream<AppUser?> session) => MaterialApp(
  home: SessionGate(
    authStateStream: session,
    signedInBuilder: (_, user) =>
        Scaffold(body: Text('signed in: ${user.uid}')),
  ),
);

void main() {
  testWidgets('waits for restored auth instead of showing the sign-in home', (
    tester,
  ) async {
    final session = StreamController<AppUser?>();
    addTearDown(session.close);
    await tester.pumpWidget(_gate(session.stream));
    expect(find.text('ログイン状態を確認しています…'), findsOneWidget);
    expect(find.text(AppStrings.homeTitle), findsNothing);
    session.add(user);
    await tester.pumpAndSettle();
    expect(find.text('signed in: parent'), findsOneWidget);
    expect(find.text(AppStrings.homeTitle), findsNothing);
  });

  testWidgets(
    'a fresh launch restores the same saved user without logging in',
    (tester) async {
      await tester.pumpWidget(_gate(Stream.value(user)));
      await tester.pumpAndSettle();
      expect(find.text('signed in: parent'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_gate(Stream.value(user)));
      await tester.pumpAndSettle();
      expect(find.text('signed in: parent'), findsOneWidget);
      expect(find.text(AppStrings.loginTitle), findsNothing);
    },
  );

  testWidgets(
    'signed-out users see the original home through the real app router',
    (tester) async {
      await tester.pumpWidget(GyuttoApp(authStateStream: Stream.value(null)));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.homeTitle), findsOneWidget);
    },
  );

  testWidgets(
    'auth removal drops signed-in content and an account switch updates it',
    (tester) async {
      final session = StreamController<AppUser?>();
      addTearDown(session.close);
      await tester.pumpWidget(_gate(session.stream));
      session.add(user);
      await tester.pumpAndSettle();
      expect(find.text('signed in: parent'), findsOneWidget);
      session.add(null);
      await tester.pumpAndSettle();
      expect(find.text('signed in: parent'), findsNothing);
      expect(find.text(AppStrings.homeTitle), findsOneWidget);
      session.add(
        const AppUser(
          uid: 'child',
          displayName: '子ども',
          email: null,
          familyId: null,
          role: AppUserRole.unknown,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('signed in: child'), findsOneWidget);
      expect(find.text('signed in: parent'), findsNothing);
    },
  );

  testWidgets(
    'an auth error can be retried without discarding the saved session',
    (tester) async {
      final auth = _Auth();
      await tester.pumpWidget(
        MaterialApp(
          home: SessionGate(
            authRepository: auth,
            signedInBuilder: (_, user) =>
                Scaffold(body: Text('signed in: ${user.uid}')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('ログイン状態を確認できませんでした'), findsOneWidget);
      expect(find.text(AppStrings.homeTitle), findsNothing);
      await tester.tap(find.text('もう一度試す'));
      await tester.pumpAndSettle();
      expect(find.text('signed in: parent'), findsOneWidget);
      expect(auth.attempts, 2);
    },
  );
}
