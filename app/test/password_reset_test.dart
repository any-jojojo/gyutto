import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/features/auth/presentation/login_screen.dart';
import 'package:gyutto/features/auth/presentation/password_reset_screen.dart';
import 'package:gyutto/repositories/auth_repository.dart';

class _Repository extends Fake implements AuthRepository {
  final emails = <String>[];
  Future<void> Function()? send;
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    emails.add(email);
    await send?.call();
  }
}

class _Auth extends Fake implements FirebaseAuth {
  String? language;
  String? email;
  String? error;
  @override
  Future<void> setLanguageCode(String? code) async {
    language = code;
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    this.email = email;
    if (error != null) throw FirebaseAuthException(code: error!);
  }
}

void main() {
  test('repository sends Japanese email and trims the address', () async {
    final auth = _Auth();
    await AuthRepository(
      firebaseAuth: auth,
    ).sendPasswordResetEmail(' parent@example.com ');
    expect(auth.email, 'parent@example.com');
    expect(auth.language, 'ja');
  });
  test(
    'repository does not disclose unknown accounts and preserves network failures',
    () async {
      final auth = _Auth()..error = 'user-not-found';
      final repository = AuthRepository(firebaseAuth: auth);
      await repository.sendPasswordResetEmail('missing@example.com');
      auth.error = 'network-request-failed';
      await expectLater(
        repository.sendPasswordResetEmail('parent@example.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
  );
  testWidgets('login offers recovery with the email already entered', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authRepository: repository)),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'parent@example.com',
    );
    await tester.ensureVisible(find.text('パスワードを忘れた方'));
    await tester.tap(find.text('パスワードを忘れた方'));
    await tester.pumpAndSettle();
    expect(find.text('パスワードの再設定'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'parent@example.com'),
      findsOneWidget,
    );
    await tester.tap(find.text('再設定メールを送信'));
    await tester.pumpAndSettle();
    expect(repository.emails, ['parent@example.com']);
    expect(find.textContaining('登録されている場合'), findsOneWidget);
    await tester.tap(find.text('ログイン画面に戻る'));
    await tester.pumpAndSettle();
    expect(find.text('パスワードを忘れた方'), findsOneWidget);
  });
  testWidgets('empty and invalid emails do not send requests', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(home: PasswordResetScreen(authRepository: repository)),
    );
    await tester.tap(find.text('再設定メールを送信'));
    await tester.pump();
    expect(find.text('メールアドレスを入力してください。'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'bad@email@address');
    await tester.tap(find.text('再設定メールを送信'));
    await tester.pump();
    expect(find.text('メールアドレスを確認してください。'), findsOneWidget);
    expect(repository.emails, isEmpty);
  });
  for (final code in ['network-request-failed', 'too-many-requests']) {
    testWidgets('$code allows retry without claiming success', (tester) async {
      final repository = _Repository()
        ..send = () async => throw FirebaseAuthException(code: code);
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordResetScreen(
            initialEmail: 'parent@example.com',
            authRepository: repository,
          ),
        ),
      );
      await tester.tap(find.text('再設定メールを送信'));
      await tester.pumpAndSettle();
      expect(find.textContaining('登録されている場合'), findsNothing);
      expect(
        find.textContaining(
          code == 'too-many-requests' ? '送信回数が多い' : '通信できませんでした',
        ),
        findsOneWidget,
      );
      repository.send = null;
      await tester.tap(find.text('再設定メールを送信'));
      await tester.pumpAndSettle();
      expect(find.textContaining('登録されている場合'), findsOneWidget);
    });
  }
  testWidgets('pending send is not duplicated and tolerates navigating away', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repository = _Repository()..send = () => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetScreen(
          initialEmail: 'parent@example.com',
          authRepository: repository,
        ),
      ),
    );
    await tester.tap(find.text('再設定メールを送信'));
    await tester.pump();
    expect(find.text('送信中…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.emails, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
