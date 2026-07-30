import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family.dart';
import '../models/family_member.dart';
import '../services/firebase_firestore_service.dart';

class FamilyRepository {
  FamilyRepository({FirebaseFirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirebaseFirestoreService();

  final FirebaseFirestoreService _firestoreService;

  Stream<Family?> watchFamily(String familyId) {
    return _firestoreService.family(familyId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return Family.fromSnapshot(snapshot);
    });
  }

  Stream<List<FamilyMember>> watchMembers(String familyId) {
    return _firestoreService
        .members(familyId)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(FamilyMember.fromSnapshot).toList();
        });
  }

  Future<String> createFamily({
    required String name,
    required String adminUserId,
    required String adminDisplayName,
  }) async {
    final familyReference = _firestoreService.families.doc();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(familyReference, {
      'name': name,
      'adminUserId': adminUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_firestoreService.members(familyReference.id).doc(adminUserId), {
      'userId': adminUserId,
      'displayName': adminDisplayName,
      'role': 'familyAdmin',
      'status': 'active',
      'createdBy': adminUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_firestoreService.user(adminUserId), {
      'displayName': adminDisplayName,
      'familyId': familyReference.id,
      'role': 'familyAdmin',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    return familyReference.id;
  }
}
