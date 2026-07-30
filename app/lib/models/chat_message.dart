import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.text,
    required this.readBy,
    required this.createdAt,
  });

  factory ChatMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final readByData = data['readBy'] as Map<String, dynamic>? ?? {};

    return ChatMessage(
      id: snapshot.id,
      senderUserId: data['senderUserId'] as String? ?? '',
      senderDisplayName: data['senderDisplayName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      readBy: readByData.map((userId, value) {
        final valueMap = value as Map<String, dynamic>? ?? {};
        return MapEntry(userId, ReadReceipt.fromJson(valueMap));
      }),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String senderUserId;
  final String senderDisplayName;
  final String text;
  final Map<String, ReadReceipt> readBy;
  final DateTime? createdAt;
}

class ReadReceipt {
  const ReadReceipt({required this.displayName, required this.readAt});

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    return ReadReceipt(
      displayName: json['displayName'] as String? ?? '',
      readAt: (json['readAt'] as Timestamp?)?.toDate(),
    );
  }

  final String displayName;
  final DateTime? readAt;
}
