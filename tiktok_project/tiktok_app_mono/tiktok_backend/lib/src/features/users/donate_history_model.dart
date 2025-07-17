import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class DonateHistory {
  final ObjectId? id;
  final ObjectId fromUserId;
  final ObjectId toUserId;
  final int amount;
  final String? donateProofImageUrl; // Ảnh xác nhận đã donate
  final DateTime createdAt;

  DonateHistory({
    this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.donateProofImageUrl,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'donateProofImageUrl': donateProofImageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DonateHistory.fromMap(Map<String, dynamic> map) {
    return DonateHistory(
      id: map['_id'] as ObjectId?,
      fromUserId: map['fromUserId'] is String ? ObjectId.fromHexString(map['fromUserId']) : map['fromUserId'] as ObjectId,
      toUserId: map['toUserId'] is String ? ObjectId.fromHexString(map['toUserId']) : map['toUserId'] as ObjectId,
      amount: map['amount'] as int,
      donateProofImageUrl: map['donateProofImageUrl'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
} 