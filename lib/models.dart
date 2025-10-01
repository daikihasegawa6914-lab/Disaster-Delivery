import 'package:cloud_firestore/cloud_firestore.dart';

// 👶 簡単に言うと：「配達要請データの設計図」
class DeliveryRequest {
  final String id;
  final String item;              // 欲しいもの
  final String requesterName;     // 要請者名
  final GeoPoint location;        // 場所
  final DateTime timestamp;       // 要請時刻
  final String status;            // 状態
  final String priority;          // 緊急度
  final String? deliveryPersonId; // 配達員ID（配達中の場合）
  final String? phone;            // 連絡先（任意）

  DeliveryRequest({
    required this.id,
    required this.item,
    required this.requesterName,
    required this.location,
    required this.timestamp,
    required this.status,
    required this.priority,
    this.deliveryPersonId,
    this.phone,
  });

  // Firestoreからデータを取得するときの変換
  factory DeliveryRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeliveryRequest(
      id: doc.id,
      item: data['item'] ?? '',
      requesterName: data['name'] ?? '匿名さん',
      location: data['location'] ?? const GeoPoint(35.681236, 139.767125),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'waiting',
      priority: data['priority'] ?? 'medium',
      deliveryPersonId: data['deliveryPersonId'],
      phone: data['phone'],
    );
  }

  // Firestoreに保存するときの変換
  Map<String, dynamic> toFirestore() {
    return {
      'item': item,
      'name': requesterName,
      'location': location,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'priority': priority,
      'deliveryPersonId': deliveryPersonId,
      'phone': phone,
    };
  }

  // 状態を変更した新しいインスタンスを作成
  DeliveryRequest copyWith({
    String? status,
    String? deliveryPersonId,
  }) {
    return DeliveryRequest(
      id: id,
      item: item,
      requesterName: requesterName,
      location: location,
      timestamp: timestamp,
      status: status ?? this.status,
      priority: priority,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      phone: phone,
    );
  }

  // 緊急度に応じた色を返す
  String get priorityColor {
    switch (priority) {
      case 'high': return '🔴'; // 赤：緊急
      case 'medium': return '🟡'; // 黄：普通
      case 'low': return '🟢'; // 緑：低い
      default: return '🟡';
    }
  }

  // 状態に応じたアイコンを返す
  String get statusIcon {
    switch (status) {
      case 'waiting': return '⏳'; // 待機中
      case 'delivering': return '🚚'; // 配達中
      case 'completed': return '✅'; // 完了
      default: return '❓';
    }
  }
}

// 配達員情報（将来的に使用）
class DeliveryPerson {
  final String id;
  final String name;
  final GeoPoint? currentLocation;
  final List<String> activeDeliveries;

  DeliveryPerson({
    required this.id,
    required this.name,
    this.currentLocation,
    required this.activeDeliveries,
  });
}