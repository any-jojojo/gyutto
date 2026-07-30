import 'package:cloud_firestore/cloud_firestore.dart';

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.adminUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Family.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return Family(
      id: snapshot.id,
      name: data['name'] as String? ?? '',
      adminUserId: data['adminUserId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String name;
  final String adminUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
