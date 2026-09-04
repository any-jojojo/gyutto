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
