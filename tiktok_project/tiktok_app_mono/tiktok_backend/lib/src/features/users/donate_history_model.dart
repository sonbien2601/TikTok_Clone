// tiktok_backend/lib/src/features/donate/domain/models/donate_history_model.dart
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class DonateHistory {
  final ObjectId? id;
  final ObjectId fromUserId;
  final ObjectId toUserId;
  final int amount;
  final String? donateProofImageUrl; // Ảnh xác nhận đã donate
  final DateTime createdAt;
  final DateTime updatedAt;

  DonateHistory({
    this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.donateProofImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : this.createdAt = createdAt ?? DateTime.now(),
       this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) '_id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'donateProofImageUrl': donateProofImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DonateHistory.fromMap(Map<String, dynamic> map) {
    return DonateHistory(
      id: map['_id'] as ObjectId?,
      fromUserId: map['fromUserId'] is String 
          ? ObjectId.fromHexString(map['fromUserId']) 
          : map['fromUserId'] as ObjectId,
      toUserId: map['toUserId'] is String 
          ? ObjectId.fromHexString(map['toUserId']) 
          : map['toUserId'] as ObjectId,
      amount: map['amount'] as int,
      donateProofImageUrl: map['donateProofImageUrl'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  DonateHistory copyWith({
    ObjectId? id,
    ObjectId? fromUserId,
    ObjectId? toUserId,
    int? amount,
    String? donateProofImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DonateHistory(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      amount: amount ?? this.amount,
      donateProofImageUrl: donateProofImageUrl ?? this.donateProofImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DonateHistory{id: $id, fromUserId: $fromUserId, toUserId: $toUserId, '
           'amount: $amount, donateProofImageUrl: $donateProofImageUrl, '
           'createdAt: $createdAt, updatedAt: $updatedAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DonateHistory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fromUserId == other.fromUserId &&
          toUserId == other.toUserId &&
          amount == other.amount &&
          donateProofImageUrl == other.donateProofImageUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      fromUserId.hashCode ^
      toUserId.hashCode ^
      amount.hashCode ^
      donateProofImageUrl.hashCode;
}