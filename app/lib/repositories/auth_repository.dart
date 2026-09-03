import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) {
        return null;
      }

      return AppUser.fromFirebaseUser(user);
    });
  }

  AppUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return null;
    }

    return AppUser.fromFirebaseUser(user);
  }

  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;

    if (user == null) {
      throw const AuthException('ログインユーザーを確認できませんでした。');
    }

    return AppUser.fromFirebaseUser(user);
  }

  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;

    if (user == null) {
      throw const AuthException('登録ユーザーを確認できませんでした。');
    }

    return AppUser.fromFirebaseUser(user, role: AppUserRole.familyAdmin);
  }

  Future<AppUser> signInWithCustomToken(String token) async {
    final credential = await _firebaseAuth.signInWithCustomToken(token);
    final user = credential.user;

    if (user == null) {
      throw const AuthException('ログインユーザーを確認できませんでした。');
    }

    return AppUser.fromFirebaseUser(user, role: AppUserRole.child);
  }

  Future<AppUser> startNewAnonymousChildSession() async {
    if (_firebaseAuth.currentUser != null) {
      await _firebaseAuth.signOut();
    }

    final credential = await _firebaseAuth.signInAnonymously();
    final user = credential.user;

    if (user == null) {
      throw const AuthException('子どもアカウントを開始できませんでした。');
    }

    return AppUser.fromFirebaseUser(user, role: AppUserRole.child);
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
