import '../models/password_reset_request.dart';
import '../services/firebase_functions_service.dart';
import '../services/firebase_firestore_service.dart';

class PasswordResetRepository {
  PasswordResetRepository({
    FirebaseFunctionsService? functionsService,
    FirebaseFirestoreService? firestoreService,
  }) : _functionsService = functionsService ?? FirebaseFunctionsService(),
       _firestoreService = firestoreService ?? FirebaseFirestoreService();

  final FirebaseFunctionsService _functionsService;
  final FirebaseFirestoreService _firestoreService;

  Stream<List<PasswordResetRequest>> watchPendingRequests(String familyId) {
    return _firestoreService
        .passwordResetRequests(familyId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(PasswordResetRequest.fromSnapshot).toList();
        });
  }

  Future<ApprovePasswordResetResult> approveChildPasswordReset({
    required String familyId,
    required String requestId,
    required bool approve,
  }) async {
    final data = await _functionsService.call('approveChildPasswordReset', {
      'familyId': familyId,
      'requestId': requestId,
      'approve': approve,
    });

    return ApprovePasswordResetResult.fromJson(data);
  }
}

class ApprovePasswordResetResult {
  const ApprovePasswordResetResult({
    required this.requestId,
    required this.status,
    required this.approvedBy,
  });

  factory ApprovePasswordResetResult.fromJson(Map<String, dynamic> json) {
    return ApprovePasswordResetResult(
      requestId: json['requestId'] as String? ?? '',
      status: PasswordResetRequestStatus.fromJson(json['status'] as String?),
      approvedBy: json['approvedBy'] as String? ?? '',
    );
  }

  final String requestId;
  final PasswordResetRequestStatus status;
  final String approvedBy;
}
