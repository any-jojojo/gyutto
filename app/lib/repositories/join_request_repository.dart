import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/join_request.dart';
import '../services/firebase_firestore_service.dart';
import '../services/firebase_functions_service.dart';

class JoinRequestRepository {
  JoinRequestRepository({
    FirebaseFirestoreService? firestoreService,
    FirebaseFunctionsService? functionsService,
  }) : _firestoreService = firestoreService ?? FirebaseFirestoreService(),
       _functionsService = functionsService ?? FirebaseFunctionsService();

  final FirebaseFirestoreService _firestoreService;
  final FirebaseFunctionsService _functionsService;

  Future<void> approveForInvite({
    required String familyId,
    required String inviteId,
  }) async {
    final snapshot = await _firestoreService
        .joinRequests(familyId)
        .where('inviteId', isEqualTo: inviteId)
        .get(const GetOptions(source: Source.server));
    final pending = snapshot.docs
        .where((document) => document.data()['status'] == 'pending')
        .toList();
    if (pending.isEmpty) {
      throw StateError('この招待の承認待ち申請はありません。子どもが参加を申請した後にもう一度お試しください。');
    }
    if (pending.length != 1) {
      throw StateError('申請を特定できません。トップページの参加申請一覧をご確認ください。');
    }
    await review(familyId: familyId, userId: pending.single.id, approve: true);
  }

  Stream<List<JoinRequest>> watchPending(String familyId) {
    return _firestoreService
        .joinRequests(familyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs.map(JoinRequest.fromSnapshot).toList();
          requests.sort((a, b) {
            final aDate =
                a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aDate.compareTo(bDate);
          });
          return requests;
        });
  }

  Future<void> review({
    required String familyId,
    required String userId,
    required bool approve,
  }) async {
    await _functionsService.call('reviewChildJoinRequest', {
      'familyId': familyId,
      'userId': userId,
      'decision': approve ? 'approved' : 'rejected',
    });
  }
}
