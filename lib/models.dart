import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Color と Colors のため

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

// 🏥 避難所情報
class Shelter {
  final String id;
  final String name;              // 避難所名
  final String address;           // 住所
  final GeoPoint location;        // 位置座標
  final int capacity;             // 収容人数
  final int currentOccupancy;     // 現在の利用者数
  final List<String> facilities;  // 施設設備
  final String status;            // 状態 (open, full, closed)
  final String? contactPhone;     // 連絡先
  final DateTime lastUpdated;     // 最終更新日時

  Shelter({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.capacity,
    required this.currentOccupancy,
    required this.facilities,
    required this.status,
    this.contactPhone,
    required this.lastUpdated,
  });

  // Firestoreからデータを取得するときの変換
  factory Shelter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Shelter(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      capacity: data['capacity'] ?? 0,
      currentOccupancy: data['currentOccupancy'] ?? 0,
      facilities: List<String>.from(data['facilities'] ?? []),
      status: data['status'] ?? 'unknown',
      contactPhone: data['contactPhone'],
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Firestoreに保存するときの変換
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'location': location,
      'capacity': capacity,
      'currentOccupancy': currentOccupancy,
      'facilities': facilities,
      'status': status,
      'contactPhone': contactPhone,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // 空き状況のパーセンテージ
  double get occupancyRate => capacity > 0 ? (currentOccupancy / capacity) : 0.0;

  // 状態に応じたアイコン
  String get statusIcon {
    switch (status) {
      case 'open': return '🟢'; // 利用可能
      case 'full': return '🔴'; // 満員
      case 'closed': return '⚫'; // 閉鎖
      default: return '🟡'; // 不明
    }
  }

  // 空き状況の色
  Color get occupancyColor {
    if (occupancyRate < 0.7) return Colors.green;
    if (occupancyRate < 0.9) return Colors.orange;
    return Colors.red;
  }
}