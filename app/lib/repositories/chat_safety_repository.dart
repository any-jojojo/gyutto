import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_safety_state.dart';
import '../services/firebase_functions_service.dart';

class ChatSafetyRepository {
  Stream<ChatSafetyState> watchState(String familyId, String uid) {
    final db = FirebaseFirestore.instance;
    return Stream<ChatSafetyState>.multi((controller) {
      Map<String, dynamic>? member;
      Map<String, dynamic>? access;
      var memberFromServer = false;
      var accessFromServer = false;
      void emit() => controller.add(
        ChatSafetyState(
          role: member?['role'] as String? ?? 'unknown',
          active: member?['status'] == 'active',
          safetyAccepted: access?['safetyVersion'] == 1,
          adultConfirmed: access?['adultVersion'] == 1,
          permission: access?['permissionVersion'] == 1
              ? (access?['permission'] as String? ?? 'pending')
              : 'pending',
          serverVerified: memberFromServer && accessFromServer,
        ),
      );
      final membership = db
          .doc('families/$familyId/members/$uid')
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
            member = snapshot.data();
            memberFromServer = !snapshot.metadata.isFromCache;
            emit();
          }, onError: controller.addError);
      final consent = db
          .doc('families/$familyId/chatAccess/$uid')
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
            access = snapshot.data();
            accessFromServer = !snapshot.metadata.isFromCache;
            emit();
          }, onError: controller.addError);
      controller.onCancel = () async {
        await membership.cancel();
        await consent.cancel();
      };
    });
  }

  Future<void> acknowledge(String familyId) async {
    await FirebaseFunctionsService().call('acknowledgeChatSafety', {
      'familyId': familyId,
      'version': 1,
    });
  }

  Future<void> reauthenticate(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.isAnonymous) {
      throw StateError('保護者のメールアドレスでログインしてください。');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    await user.getIdToken(true);
  }

  Future<void> confirmAdult(String familyId, String password) async {
    await reauthenticate(password);
    await FirebaseFunctionsService().call('confirmAdultForChat', {
      'familyId': familyId,
      'version': 1,
      'adultDeclaration': true,
    });
  }

  Future<void> setPermission(
    String familyId,
    String childUserId,
    String permission,
    String password,
  ) async {
    await reauthenticate(password);
    await FirebaseFunctionsService().call('setChildChatPermission', {
      'familyId': familyId,
      'childUserId': childUserId,
      'permission': permission,
    });
  }
}
