import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gyutto/features/invite/presentation/invite_child_qr_screen.dart';
import 'package:gyutto/models/app_user.dart';
import 'package:gyutto/repositories/auth_repository.dart';
import 'package:gyutto/repositories/invite_repository.dart';
import 'package:gyutto/repositories/user_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _user = AppUser(
  uid: 'parent',
  displayName: '親',
  email: 'parent@example.com',
  familyId: 'family',
  role: AppUserRole.parent,
);

class _Auth extends Fake implements AuthRepository {
  @override
  AppUser? get currentUser => _user;
}

class _Users extends Fake implements UserRepository {
  @override
  Future<AppUser?> fetchUser(String userId) async => _user;
}

class _Invites extends Fake implements InviteRepository {
  int calls = 0;
  late Future<CreateInviteResult> Function() create;
  @override
  Future<CreateInviteResult> createChildQrInvite({
    required String familyId,
    required String createdBy,
    required Uri baseUri,
  }) {
    calls++;
    return create();
  }
}

Widget _screen(_Invites invites) => MaterialApp(
  home: InviteChildQrScreen(
    authRepository: _Auth(),
    userRepository: _Users(),
    inviteRepository: invites,
  ),
);

void main() {
  testWidgets('creates and displays QR automatically on opening', (
    tester,
  ) async {
    final pending = Completer<CreateInviteResult>();
    final invites = _Invites()..create = () => pending.future;
    await tester.pumpWidget(_screen(invites));
    await tester.pump();
    expect(invites.calls, 1);
    expect(find.text('QRコードを準備しています…'), findsOneWidget);
    expect(find.text('QRコードを発行する'), findsNothing);
    pending.complete(
      CreateInviteResult(
        inviteId: 'invite',
        inviteUrl: 'https://example.com/invite',
        token: 'token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(invites.calls, 1);
  });

  testWidgets('failed automatic creation can be retried', (tester) async {
    final invites = _Invites()
      ..create = () async => throw StateError('offline');
    await tester.pumpWidget(_screen(invites));
    await tester.pumpAndSettle();
    expect(find.text('もう一度試す'), findsOneWidget);
    invites.create = () async => CreateInviteResult(
      inviteId: 'invite',
      inviteUrl: 'https://example.com/invite',
      token: 'token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await tester.tap(find.text('もう一度試す'));
    await tester.pumpAndSettle();
    expect(invites.calls, 2);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('leaving during creation handles a later failure', (
    tester,
  ) async {
    final pending = Completer<CreateInviteResult>();
    final invites = _Invites()..create = () => pending.future;
    await tester.pumpWidget(_screen(invites));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
