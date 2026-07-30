import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

enum FamilyMemberStatus {
  active,
  invited,
  disabled,
  unknown;

  factory FamilyMemberStatus.fromJson(String? value) {
    return switch (value) {
      'active' => FamilyMemberStatus.active,
      'invited' => FamilyMemberStatus.invited,
      'disabled' => FamilyMemberStatus.disabled,
      _ => FamilyMemberStatus.unknown,
    };
  }

  String toJson() {
    return switch (this) {
      FamilyMemberStatus.active => 'active',
      FamilyMemberStatus.invited => 'invited',
      FamilyMemberStatus.disabled => 'disabled',
      FamilyMemberStatus.unknown => 'unknown',
    };
  }
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyMember.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return FamilyMember(
      id: snapshot.id,
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: AppUserRole.fromJson(data['role'] as String?),
      status: FamilyMemberStatus.fromJson(data['status'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String userId;
  final String displayName;
  final AppUserRole role;
  final FamilyMemberStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
