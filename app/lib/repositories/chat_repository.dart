import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../services/firebase_firestore_service.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirebaseFirestoreService();

  final FirebaseFirestoreService _firestoreService;

  Stream<List<ChatMessage>> watchMessages(String familyId) {
    return _firestoreService
        .messages(familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(ChatMessage.fromSnapshot).toList();
        });
  }

  Future<void> sendMessage({
    required String familyId,
    required String senderUserId,
    required String senderDisplayName,
    required String text,
  }) {
    return _firestoreService.messages(familyId).add({
      'senderUserId': senderUserId,
      'senderDisplayName': senderDisplayName,
      'text': text.trim(),
      'readBy': {
        senderUserId: {
          'displayName': senderDisplayName,
          'readAt': FieldValue.serverTimestamp(),
        },
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead({
    required String familyId,
    required String messageId,
    required String userId,
    required String displayName,
  }) {
    return _firestoreService.messages(familyId).doc(messageId).set({
      'readBy': {
        userId: {
          'displayName': displayName,
          'readAt': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));
  }
}
