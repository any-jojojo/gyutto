import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseFirestoreService {
  FirebaseFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get users {
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>> get families {
    return _firestore.collection('families');
  }

  CollectionReference<Map<String, dynamic>> get parentInviteCodes {
    return _firestore.collection('parentInviteCodes');
  }

  DocumentReference<Map<String, dynamic>> user(String userId) {
    return users.doc(userId);
  }

  DocumentReference<Map<String, dynamic>> family(String familyId) {
    return families.doc(familyId);
  }

  CollectionReference<Map<String, dynamic>> members(String familyId) {
    return family(familyId).collection('members');
  }

  CollectionReference<Map<String, dynamic>> invites(String familyId) {
    return family(familyId).collection('invites');
  }

  CollectionReference<Map<String, dynamic>> messages(String familyId) {
    return family(familyId).collection('messages');
  }

  CollectionReference<Map<String, dynamic>> passwordResetRequests(
    String familyId,
  ) {
    return family(familyId).collection('passwordResetRequests');
  }
}
