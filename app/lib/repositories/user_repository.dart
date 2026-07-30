import '../models/app_user.dart';
import '../services/firebase_firestore_service.dart';

class UserRepository {
  UserRepository({FirebaseFirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirebaseFirestoreService();

  final FirebaseFirestoreService _firestoreService;

  Stream<AppUser?> watchUser(String userId) {
    return _firestoreService.user(userId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return AppUser.fromJson(snapshot.id, data);
    });
  }

  Future<AppUser?> fetchUser(String userId) async {
    final snapshot = await _firestoreService.user(userId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }

    return AppUser.fromJson(snapshot.id, data);
  }
}
