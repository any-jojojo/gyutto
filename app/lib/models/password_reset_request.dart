import 'package:cloud_firestore/cloud_firestore.dart';

enum PasswordResetRequestStatus {
  pending,
  approved,
  rejected,
  completed,
  expired,
  unknown;

  factory PasswordResetRequestStatus.fromJson(String? value) {
    return switch (value) {
      'pending' => PasswordResetRequestStatus.pending,
      'approved' => PasswordResetRequestStatus.approved,
      'rejected' => PasswordResetRequestStatus.rejected,
      'completed' => PasswordResetRequestStatus.completed,
      'expired' => PasswordResetRequestStatus.expired,
      _ => PasswordResetRequestStatus.unknown,
    };
  }
}

class PasswordResetRequest {
  const PasswordResetRequest({
    required this.id,
    required this.childUserId,
    required this.requestedBy,
    required this.approvedBy,
    required this.status,
    required this.createdAt,
    required this.approvedAt,
    required this.completedAt,
  });

  factory PasswordResetRequest.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return PasswordResetRequest(
      id: snapshot.id,
      childUserId: data['childUserId'] as String? ?? '',
      requestedBy: data['requestedBy'] as String? ?? '',
      approvedBy: data['approvedBy'] as String?,
      status: PasswordResetRequestStatus.fromJson(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String childUserId;
  final String requestedBy;
  final String? approvedBy;
  final PasswordResetRequestStatus status;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;
}
