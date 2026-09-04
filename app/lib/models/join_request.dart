import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequest {
  const JoinRequest({
    required this.userId,
    required this.displayName,
    required this.status,
    required this.requestedAt,
  });

  factory JoinRequest.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return JoinRequest(
      userId: data['userId'] as String? ?? snapshot.id,
      displayName: data['displayName'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String userId;
  final String displayName;
  final String status;
  final DateTime? requestedAt;
}
