import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

enum InviteType {
  parentInvite,
  childQrInvite,
  unknown;

  factory InviteType.fromJson(String? value) {
    return switch (value) {
      'parentInvite' => InviteType.parentInvite,
      'childQrInvite' => InviteType.childQrInvite,
      _ => InviteType.unknown,
    };
  }

  String toJson() {
    return switch (this) {
      InviteType.parentInvite => 'parentInvite',
      InviteType.childQrInvite => 'childQrInvite',
      InviteType.unknown => 'unknown',
    };
  }
}

enum InviteStatus {
  active,
  used,
  expired,
  revoked,
  unknown;

  factory InviteStatus.fromJson(String? value) {
    return switch (value) {
      'active' => InviteStatus.active,
      'used' => InviteStatus.used,
      'expired' => InviteStatus.expired,
      'revoked' => InviteStatus.revoked,
      _ => InviteStatus.unknown,
    };
  }
}

class Invite {
  const Invite({
    required this.id,
    required this.type,
    required this.targetRole,
    required this.targetMemberId,
    required this.createdBy,
    required this.expiresAt,
    required this.usedAt,
    required this.usedBy,
    required this.status,
    required this.createdAt,
  });

  factory Invite.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return Invite(
      id: snapshot.id,
      type: InviteType.fromJson(data['type'] as String?),
      targetRole: AppUserRole.fromJson(data['targetRole'] as String?),
      targetMemberId: data['targetMemberId'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      usedBy: data['usedBy'] as String?,
      status: InviteStatus.fromJson(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final InviteType type;
  final AppUserRole targetRole;
  final String? targetMemberId;
  final String createdBy;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final String? usedBy;
  final InviteStatus status;
  final DateTime? createdAt;
}
