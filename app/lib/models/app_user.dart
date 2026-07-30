import 'package:firebase_auth/firebase_auth.dart';

enum AppUserRole {
  familyAdmin,
  parent,
  child,
  unknown;

  factory AppUserRole.fromJson(String? value) {
    return switch (value) {
      'familyAdmin' => AppUserRole.familyAdmin,
      'parent' => AppUserRole.parent,
      'child' => AppUserRole.child,
      _ => AppUserRole.unknown,
    };
  }

  String toJson() {
    return switch (this) {
      AppUserRole.familyAdmin => 'familyAdmin',
      AppUserRole.parent => 'parent',
      AppUserRole.child => 'child',
      AppUserRole.unknown => 'unknown',
    };
  }

  bool get canAddParent {
    return this == AppUserRole.familyAdmin;
  }

  bool get canAddChild {
    return this == AppUserRole.familyAdmin || this == AppUserRole.parent;
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.familyId,
    required this.role,
  });

  factory AppUser.fromFirebaseUser(User user, {AppUserRole? role}) {
    return AppUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      familyId: null,
      role: role ?? AppUserRole.unknown,
    );
  }

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) {
    return AppUser(
      uid: uid,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      familyId: json['familyId'] as String?,
      role: AppUserRole.fromJson(json['role'] as String?),
    );
  }

  final String uid;
  final String? displayName;
  final String? email;
  final String? familyId;
  final AppUserRole role;

  bool get isSignedIn {
    return uid.isNotEmpty;
  }
}
