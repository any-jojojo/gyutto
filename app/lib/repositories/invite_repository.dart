import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../core/constants/app_constants.dart';
import '../models/app_user.dart';
import '../models/invite.dart';
import '../services/firebase_firestore_service.dart';
import '../services/firebase_functions_service.dart';

class InviteRepository {
  InviteRepository({
    FirebaseFunctionsService? functionsService,
    FirebaseFirestoreService? firestoreService,
  }) : _functionsService = functionsService ?? FirebaseFunctionsService(),
       _firestoreService = firestoreService ?? FirebaseFirestoreService();

  final FirebaseFunctionsService _functionsService;
  final FirebaseFirestoreService _firestoreService;

  Stream<List<Invite>> watchInvites(String familyId) {
    return _firestoreService
        .invites(familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(Invite.fromSnapshot).toList();
        });
  }

  Future<CreateInviteResult> createParentInvite({
    required String familyId,
    required String createdBy,
  }) async {
    final code = _generateInviteCode();
    final codeHash = _hashInviteCode(code);
    final inviteReference = _firestoreService.invites(familyId).doc();
    final codeReference = _firestoreService.parentInviteCodes.doc(codeHash);
    final expiresAt = DateTime.now().add(AppConstants.inviteValidityDuration);
    final batch = FirebaseFirestore.instance.batch();

    batch.set(inviteReference, {
      'type': InviteType.parentInvite.toJson(),
      'targetRole': AppUserRole.parent.toJson(),
      'codeHash': codeHash,
      'createdBy': createdBy,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'usedAt': null,
      'usedBy': null,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(codeReference, {
      'familyId': familyId,
      'inviteId': inviteReference.id,
      'type': InviteType.parentInvite.toJson(),
      'targetRole': AppUserRole.parent.toJson(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return CreateInviteResult(
      inviteId: inviteReference.id,
      inviteUrl: '',
      token: code,
      expiresAt: expiresAt,
    );
  }

  Future<CreateInviteResult> createChildQrInvite({
    required String familyId,
    required String createdBy,
    required Uri baseUri,
  }) async {
    final token = _generateInviteToken();
    final tokenHash = _hashInviteCode(token);
    final inviteReference = _firestoreService.invites(familyId).doc();
    final tokenReference = _firestoreService.childInviteTokens.doc(tokenHash);
    final expiresAt = DateTime.now().add(AppConstants.inviteValidityDuration);
    final joinUri = baseUri.replace(
      path: '/',
      queryParameters: null,
      fragment:
          '${AppRoutesPath.childInviteJoin}?token=${Uri.encodeComponent(token)}',
    );
    final batch = FirebaseFirestore.instance.batch();

    batch.set(inviteReference, {
      'type': InviteType.childQrInvite.toJson(),
      'targetRole': AppUserRole.child.toJson(),
      'tokenHash': tokenHash,
      'createdBy': createdBy,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'usedAt': null,
      'usedBy': null,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(tokenReference, {
      'familyId': familyId,
      'inviteId': inviteReference.id,
      'type': InviteType.childQrInvite.toJson(),
      'targetRole': AppUserRole.child.toJson(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return CreateInviteResult(
      inviteId: inviteReference.id,
      inviteUrl: joinUri.toString(),
      token: token,
      expiresAt: expiresAt,
    );
  }

  Future<JoinParentInviteResult> joinParentInvite({
    required String code,
    required String userId,
    required String displayName,
  }) async {
    final normalizedCode = _normalizeInviteCode(code);
    final codeHash = _hashInviteCode(normalizedCode);
    final codeReference = _firestoreService.parentInviteCodes.doc(codeHash);
    final codeSnapshot = await codeReference.get();
    final codeData = codeSnapshot.data();

    if (!codeSnapshot.exists || codeData == null) {
      throw const InviteException('招待コードが見つかりません。');
    }

    if (codeData['status'] != 'active') {
      throw const InviteException('この招待コードは利用できません。');
    }

    final expiresAt = (codeData['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      throw const InviteException('有効期限が切れました。再発行してください。');
    }

    final familyId = codeData['familyId'] as String? ?? '';
    final inviteId = codeData['inviteId'] as String? ?? '';
    if (familyId.isEmpty || inviteId.isEmpty) {
      throw const InviteException('招待情報を確認できませんでした。');
    }

    final batch = FirebaseFirestore.instance.batch();
    final inviteReference = _firestoreService.invites(familyId).doc(inviteId);

    batch.set(_firestoreService.members(familyId).doc(userId), {
      'userId': userId,
      'displayName': displayName,
      'role': AppUserRole.parent.toJson(),
      'status': 'active',
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_firestoreService.user(userId), {
      'displayName': displayName,
      'familyId': familyId,
      'role': AppUserRole.parent.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.update(inviteReference, {
      'status': 'used',
      'usedAt': FieldValue.serverTimestamp(),
      'usedBy': userId,
    });
    batch.update(codeReference, {'status': 'used'});

    await batch.commit();

    return JoinParentInviteResult(familyId: familyId);
  }

  Future<JoinChildInviteResult> joinChildInvite({
    required String token,
    required String displayName,
    required String approvedBy,
  }) async {
    final tokenHash = _hashInviteCode(token);
    final tokenReference = _firestoreService.childInviteTokens.doc(tokenHash);
    final tokenSnapshot = await tokenReference.get();
    final tokenData = tokenSnapshot.data();

    if (!tokenSnapshot.exists || tokenData == null) {
      throw const InviteException('QRコードの招待情報が見つかりません。');
    }

    if (tokenData['status'] != 'active') {
      throw const InviteException('このQRコードは利用できません。');
    }

    final expiresAt = (tokenData['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
      throw const InviteException('有効期限が切れました。再発行してください。');
    }

    final familyId = tokenData['familyId'] as String? ?? '';
    final inviteId = tokenData['inviteId'] as String? ?? '';
    if (familyId.isEmpty || inviteId.isEmpty) {
      throw const InviteException('招待情報を確認できませんでした。');
    }

    final childReference = _firestoreService.members(familyId).doc();
    final inviteReference = _firestoreService.invites(familyId).doc(inviteId);
    final batch = FirebaseFirestore.instance.batch();

    batch.set(childReference, {
      'userId': childReference.id,
      'displayName': displayName,
      'role': AppUserRole.child.toJson(),
      'status': 'active',
      'createdBy': approvedBy,
      'inviteId': inviteId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(inviteReference, {
      'status': 'used',
      'usedAt': FieldValue.serverTimestamp(),
      'usedBy': childReference.id,
    });
    batch.update(tokenReference, {'status': 'used'});

    await batch.commit();

    return JoinChildInviteResult(
      familyId: familyId,
      childMemberId: childReference.id,
    );
  }

  Future<CreateInviteResult> createInvite({
    required String familyId,
    required InviteType type,
    String? targetMemberId,
  }) async {
    final parameters = {'familyId': familyId, 'type': type.toJson()};
    if (targetMemberId != null) {
      parameters['targetMemberId'] = targetMemberId;
    }

    final data = await _functionsService.call('createInvite', parameters);

    return CreateInviteResult.fromJson(data);
  }

  Future<ValidateInviteResult> validateInvite({
    required String familyId,
    required String token,
  }) async {
    final data = await _functionsService.call('validateInvite', {
      'familyId': familyId,
      'token': token,
    });

    return ValidateInviteResult.fromJson(data);
  }

  String _generateInviteCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(
      8,
      (_) => characters[random.nextInt(characters.length)],
    ).join();

    return '${code.substring(0, 4)}-${code.substring(4)}';
  }

  String _generateInviteToken() {
    const characters =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      32,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  String _hashInviteCode(String code) {
    return sha256.convert(utf8.encode(_normalizeInviteCode(code))).toString();
  }

  String _normalizeInviteCode(String code) {
    return code.trim().replaceAll('-', '').toUpperCase();
  }
}

class AppRoutesPath {
  const AppRoutesPath._();

  static const childInviteJoin = '/invites/child/join';
}

class CreateInviteResult {
  const CreateInviteResult({
    required this.inviteId,
    required this.inviteUrl,
    required this.token,
    this.expiresAt,
  });

  factory CreateInviteResult.fromJson(Map<String, dynamic> json) {
    return CreateInviteResult(
      inviteId: json['inviteId'] as String? ?? '',
      inviteUrl: json['inviteUrl'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  final String inviteId;
  final String inviteUrl;
  final String token;
  final DateTime? expiresAt;
}

class JoinParentInviteResult {
  const JoinParentInviteResult({required this.familyId});

  final String familyId;
}

class JoinChildInviteResult {
  const JoinChildInviteResult({
    required this.familyId,
    required this.childMemberId,
  });

  final String familyId;
  final String childMemberId;
}

class InviteException implements Exception {
  const InviteException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

class ValidateInviteResult {
  const ValidateInviteResult({
    required this.inviteId,
    required this.familyId,
    required this.familyName,
    required this.type,
    required this.targetRole,
    required this.targetMemberId,
  });

  factory ValidateInviteResult.fromJson(Map<String, dynamic> json) {
    return ValidateInviteResult(
      inviteId: json['inviteId'] as String? ?? '',
      familyId: json['familyId'] as String? ?? '',
      familyName: json['familyName'] as String? ?? '',
      type: InviteType.fromJson(json['type'] as String?),
      targetRole: AppUserRole.fromJson(json['targetRole'] as String?),
      targetMemberId: json['targetMemberId'] as String?,
    );
  }

  final String inviteId;
  final String familyId;
  final String familyName;
  final InviteType type;
  final AppUserRole targetRole;
  final String? targetMemberId;
}
