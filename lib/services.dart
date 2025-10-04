import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'constants.dart';

// 👶 このファイルは「サービス層（Firebase・位置情報・配達管理）」のロジックです。
// - Firestoreや位置情報取得、配達リクエストの状態管理などをまとめています。

// 👶 簡単に言うと：「Firebaseとやりとりする専門家」
class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // コレクション名（実際のFirebase構成に合わせる）
  static const String requestsCollection = 'requests';
  static const String deliveriesCollection = 'deliveries';
  static const String sheltersCollection = 'shelters';
  static const String deliveryPersonsCollection = 'delivery_persons';

  // 📍 配達待ちの要請を取得するStream（インデックス不要バージョン）
  static Stream<List<DeliveryRequest>> getWaitingRequests() {
    return _firestore
        .collection(requestsCollection)
    // 一部ドキュメントで status が誤って 'wating' と保存されているケースを暫定吸収
    // 運用ではデータクレンジング後に whereIn -> isEqualTo へ戻す想定
    .where('status', whereIn: [RequestStatus.waiting, 'wating'])
        // orderBy を一時的に削除してインデックスエラーを回避
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryRequest.fromFirestore(doc))
            .toList());
  }

  // 🚚 特定の配達員が担当中の要請を取得
  static Stream<List<DeliveryRequest>> getMyDeliveries(String deliveryPersonId) {
    return _firestore
        .collection(requestsCollection)
  .where('deliveryPersonId', isEqualTo: deliveryPersonId)
  .where('status', whereIn: [RequestStatus.assigned, RequestStatus.delivering])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryRequest.fromFirestore(doc))
            .toList());
  }

  // 📊 自分の配達ステータス集計 (assigned, delivering, completed 直近 N など拡張余地あり)
  static Stream<Map<String, int>> getMyStatusCounts(String deliveryPersonId) {
    return _firestore
        .collection(requestsCollection)
        .where('deliveryPersonId', isEqualTo: deliveryPersonId)
        .where('status', whereIn: [RequestStatus.assigned, RequestStatus.delivering])
        .snapshots()
        .map((snap) {
          int assigned = 0;
          int delivering = 0;
          for (final d in snap.docs) {
            final data = d.data();
            final status = data['status'];
            if (status == RequestStatus.assigned) assigned++;
            else if (status == RequestStatus.delivering) delivering++;
          }
          return {
            'assigned': assigned,
            'delivering': delivering,
          };
        });
  }

  // � 避難所情報を取得
  static Stream<List<Shelter>> getShelters() {
    return _firestore
        .collection(sheltersCollection)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Shelter.fromFirestore(doc))
            .toList());
  }


  // =========================
  // 🔄 共通トランザクションユーティリティ
  // =========================
  static Future<bool> _txnUpdateRequest({
    required String requestId,
    required bool Function(Map<String, dynamic> current) precondition,
    required Map<String, dynamic> Function(Map<String, dynamic> current) buildUpdate,
  }) async {
    final ref = _firestore.collection(requestsCollection).doc(requestId);
    try {
      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final data = snap.data() as Map<String, dynamic>;
        if (!precondition(data)) return false;
        final upd = buildUpdate(data);
        tx.update(ref, {
          ...upd,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('⚠️ _txnUpdateRequest failed: $e');
      return false;
    }
  }

  // 🤝 要請を引き受ける（assign 専用。UI上は「この配達を引き受ける」）
  // 成功: true / 競合・不正状態: false
  static Future<bool> assignDelivery(String requestId, String deliveryPersonId) async {
    return _txnUpdateRequest(
      requestId: requestId,
      precondition: (cur) {
        final status = cur['status'];
        final dp = cur['deliveryPersonId'];
        final isWaiting = status == RequestStatus.waiting || status == 'wating';
        final unclaimed = dp == null || (dp is String && dp.isEmpty);
        return isWaiting && unclaimed;
      },
      buildUpdate: (cur) => {
        'status': RequestStatus.assigned,
        'deliveryPersonId': deliveryPersonId,
        'assignedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  // ↩️ 引き受け解除 (assigned -> waiting)。配達開始前のみ許可。署名は従来通り void のまま（UI 影響最小化）
  static Future<void> cancelAssignment(String requestId, String deliveryPersonId) async {
    await _txnUpdateRequest(
      requestId: requestId,
      precondition: (cur) => cur['status'] == RequestStatus.assigned && cur['deliveryPersonId'] == deliveryPersonId,
      buildUpdate: (cur) => {
        'status': RequestStatus.waiting,
        'deliveryPersonId': null,
        'canceledAt': FieldValue.serverTimestamp(),
        'canceledBy': deliveryPersonId,
      },
    );
  }

  // 🚀 配達開始（assigned → delivering）
  static Future<void> startDelivery(String requestId, String deliveryPersonId) async {
    await _txnUpdateRequest(
      requestId: requestId,
      precondition: (cur) => cur['status'] == RequestStatus.assigned && cur['deliveryPersonId'] == deliveryPersonId,
      buildUpdate: (cur) => {
        'status': RequestStatus.delivering,
        'deliveryPersonId': deliveryPersonId,
        'deliveryStartedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  // ✅ 配達を完了する (delivering → completed)
  static Future<void> completeDelivery(String requestId) async {
    await _txnUpdateRequest(
      requestId: requestId,
      precondition: (cur) => cur['status'] == RequestStatus.delivering,
      buildUpdate: (cur) => {
        'status': RequestStatus.completed,
        'completedTime': FieldValue.serverTimestamp(),
      },
    );
  }

  // � 再利用: completed -> waiting (管理者UI 専用。deliveryPersonId を除去 / reopenCount 増分)
  static Future<bool> reopenRequest(String requestId, String adminUid) async {
    // ここでは adminUid の検証は Firestore ルール側(E条件)に委譲。アプリ側では最小限のトランザクションのみ。
    return _txnUpdateRequest(
      requestId: requestId,
      precondition: (cur) => cur['status'] == RequestStatus.completed,
      buildUpdate: (cur) {
        final currentCount = (cur['reopenCount'] is int) ? cur['reopenCount'] as int : 0;
        return {
          'status': RequestStatus.waiting,
          'deliveryPersonId': null,
          'reopenedAt': FieldValue.serverTimestamp(),
          'reopenCount': currentCount + 1,
          // completedTime は履歴保持のため残す（過去完了時刻の参照用途）
        };
      },
    );
  }

  // �📊 配達統計を記録（任意）
  static Future<void> recordDeliveryStats(String requestId, String deliveryPersonId) async {
    await _firestore.collection(deliveriesCollection).add({
      'requestId': requestId,
      'deliveryPersonId': deliveryPersonId,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  // 🆘 緊急要請のみを取得
  static Stream<List<DeliveryRequest>> getEmergencyRequests() {
    return _firestore
        .collection(requestsCollection)
    // 緊急判定でも 'wating' タイポを吸収
    .where('status', whereIn: [RequestStatus.waiting, 'wating'])
  .where('priority', isEqualTo: RequestPriority.high)
        // .orderBy('timestamp', descending: false) // 一時的にコメントアウト
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryRequest.fromFirestore(doc))
            .toList());
  }
}

// 👶 簡単に言うと：「位置情報を扱う専門家」
class LocationService {
  // 現在地を取得
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('位置情報取得エラー: $e');
      return null;
    }
  }

  // 2点間の距離を計算（km）
  static double calculateDistance(GeoPoint from, GeoPoint to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    ) / 1000; // メートルをキロメートルに変換
  }

  // 現在地から要請場所までの距離を計算
  static Future<double?> getDistanceToRequest(DeliveryRequest request) async {
    final currentPos = await getCurrentLocation();
    if (currentPos == null) return null;
    
    return calculateDistance(
      GeoPoint(currentPos.latitude, currentPos.longitude),
      request.location,
    );
  }
}

// 👶 簡単に言うと：「配達員のIDを管理する専門家」
class DeliveryPersonService {
  // 簡易的な配達員ID（実際のアプリではもっと複雑な認証が必要）
  static String _deliveryPersonId = '';

  static String get currentDeliveryPersonId {
    if (_deliveryPersonId.isEmpty) {
      // デバイスの一意IDを生成（簡易版）
      _deliveryPersonId = 'delivery_${DateTime.now().millisecondsSinceEpoch}';
    }
    return _deliveryPersonId;
  }

  // 配達員名を設定（任意）
  static void setDeliveryPersonName(String name) {
    // 将来的にFirestoreに保存
  }
}

// 🏥 避難所情報を管理するサービス
class ShelterService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String sheltersCollection = 'shelters';

  // 全ての避難所を取得
  static Stream<List<Shelter>> getAllShelters() {
    return _firestore
        .collection(sheltersCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Shelter.fromFirestore(doc))
            .toList());
  }

  // 利用可能な避難所のみを取得
  static Stream<List<Shelter>> getAvailableShelters() {
    return _firestore
        .collection(sheltersCollection)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Shelter.fromFirestore(doc))
            .toList());
  }

  // 近くの避難所を取得（簡易版）
  static Future<List<Shelter>> getNearByShelters(GeoPoint userLocation, {double radiusKm = 5.0}) async {
    final snapshot = await _firestore.collection(sheltersCollection).get();
    final shelters = snapshot.docs.map((doc) => Shelter.fromFirestore(doc)).toList();
    
    // 距離でフィルタリング
    return shelters.where((shelter) {
      final distance = LocationService.calculateDistance(userLocation, shelter.location);
      return distance <= radiusKm;
    }).toList()
      ..sort((a, b) {
        final distanceA = LocationService.calculateDistance(userLocation, a.location);
        final distanceB = LocationService.calculateDistance(userLocation, b.location);
        return distanceA.compareTo(distanceB);
      });
  }

  // 避難所情報を更新
  static Future<void> updateShelterOccupancy(String shelterId, int newOccupancy) async {
    await _firestore.collection(sheltersCollection).doc(shelterId).update({
      'currentOccupancy': newOccupancy,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // 初期の避難所データを作成（開発用）
  static Future<void> createInitialShelterData() async {
    final shelters = [
      {
        'name': '新宿区立第一中学校',
        'address': '東京都新宿区西新宿1-1-1',
        'location': const GeoPoint(35.6896, 139.7006),
        'capacity': 500,
        'currentOccupancy': 230,
        'facilities': ['体育館', '教室', '給水設備', '医療室'],
        'status': 'open',
        'contactPhone': '03-1234-5678',
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      {
        'name': '渋谷区民センター',
        'address': '東京都渋谷区渋谷1-1-1',
        'location': const GeoPoint(35.6598, 139.7036),
        'capacity': 300,
        'currentOccupancy': 280,
        'facilities': ['ホール', '会議室', '給水設備'],
        'status': 'open',
        'contactPhone': '03-2345-6789',
        'lastUpdated': FieldValue.serverTimestamp(),
      },
      {
        'name': '港区立総合体育館',
        'address': '東京都港区芝公園1-1-1',
        'location': const GeoPoint(35.6585, 139.7454),
        'capacity': 800,
        'currentOccupancy': 150,
        'facilities': ['体育館', 'プール', '給水設備', '医療室', '調理室'],
        'status': 'open',
        'contactPhone': '03-3456-7890',
        'lastUpdated': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();
    for (var shelter in shelters) {
      final docRef = _firestore.collection(sheltersCollection).doc();
      batch.set(docRef, shelter);
    }
    
    await batch.commit();
    debugPrint('✅ 避難所データを作成しました');
  }

  // 指定リスト（名前 + 緯度経度）をシード（存在しない name のみ追加）
  static Future<void> seedProvidedSheltersIfMissing() async {
    final seeds = [
      {'name': '真田堀運動場', 'lat': 35.68278, 'lng': 139.731059},
      {'name': '外濠公園', 'lat': 35.68864, 'lng': 139.73097},
      {'name': '麹町小学校', 'lat': 35.685573, 'lng': 139.739317},
      {'name': '九段小学校', 'lat': 35.690366, 'lng': 139.740845},
      {'name': '番町小学校', 'lat': 35.688163, 'lng': 139.734126},
      {'name': '麹町中学校', 'lat': 35.680493, 'lng': 139.73867},
      {'name': '富士見みらい館', 'lat': 35.697182, 'lng': 139.746403},
      {'name': '神田一橋中学校', 'lat': 35.694133, 'lng': 139.756828},
      {'name': '神田さくら館', 'lat': 35.693327, 'lng': 139.768393},
      {'name': '昌平童夢館', 'lat': 35.701306, 'lng': 139.769766},
      {'name': 'アーツ千代田3331', 'lat': 35.704267, 'lng': 139.770632},
    ];

    WriteBatch batch = _firestore.batch();
    int addCount = 0;
    for (final s in seeds) {
      final existing = await _firestore
          .collection(sheltersCollection)
          .where('name', isEqualTo: s['name'])
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;
      final docRef = _firestore.collection(sheltersCollection).doc();
      batch.set(docRef, {
        'name': s['name'],
        'address': '',
        'location': GeoPoint(s['lat'] as double, s['lng'] as double),
        'capacity': 300,
        'currentOccupancy': 0,
        'facilities': [],
        'status': 'open',
        'contactPhone': null,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      addCount++;
    }
    if (addCount > 0) {
      await batch.commit();
      debugPrint('✅ shelter seed inserted: $addCount');
    } else {
      debugPrint('ℹ️ shelter seed: no new docs');
    }
  }

  // 🧹 シードした簡易避難所( address=='' かつ facilities 空など )を削除
  static Future<int> deleteSeededSimpleShelters() async {
    final snap = await _firestore
        .collection(sheltersCollection)
        .where('address', isEqualTo: '')
        .get();
    if (snap.docs.isEmpty) {
      debugPrint('🧹 削除対象シード避難所なし');
      return 0;
    }
    int deleted = 0;
    WriteBatch batch = _firestore.batch();
    for (final d in snap.docs) {
      final data = d.data();
      final facilities = data['facilities'];
      final capacity = data['capacity'];
      final currentOccupancy = data['currentOccupancy'];
      if ((facilities is List && facilities.isEmpty) && capacity == 300 && currentOccupancy == 0) {
        batch.delete(d.reference);
        deleted++;
      }
    }
    if (deleted > 0) {
      await batch.commit();
      debugPrint('🧹 シード避難所削除: $deleted 件');
    } else {
      debugPrint('🧹 条件一致なし (address=='' はあるが判定除外)');
    }
    return deleted;
  }
}