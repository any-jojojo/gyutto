import 'package:firebase_auth/firebase_auth.dart';

enum AppUserRole {
  familyAdmin,
  parent,
  child,
  unknown;

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
    required this.role,
  });

  factory AppUser.fromFirebaseUser(User user, {AppUserRole? role}) {
    return AppUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      role: role ?? AppUserRole.unknown,
    );
  }

  final String uid;
  final String? displayName;
  final String? email;
  final AppUserRole role;

  bool get isSignedIn {
    return uid.isNotEmpty;
  }
}
