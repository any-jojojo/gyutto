import '../models/app_user.dart';
import '../models/invite.dart';
import '../services/firebase_functions_service.dart';
import '../services/firebase_firestore_service.dart';

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
}

class CreateInviteResult {
  const CreateInviteResult({
    required this.inviteId,
    required this.inviteUrl,
    required this.token,
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
