import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'models.dart';

// 👶 簡単に言うと：「Firebaseとやりとりする専門家」
class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // コレクション名（友人のアプリと共通）
  static const String requestsCollection = 'requests';
  static const String deliveriesCollection = 'deliveries';

  // 📍 配達待ちの要請を取得するStream
  static Stream<List<DeliveryRequest>> getWaitingRequests() {
    return _firestore
        .collection(requestsCollection)
        .where('status', isEqualTo: 'waiting')
        // .orderBy('timestamp', descending: false) // 一時的にコメントアウト
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
        .where('status', isEqualTo: 'delivering')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryRequest.fromFirestore(doc))
            .toList());
  }

  // 🎯 配達を開始する
  static Future<void> startDelivery(String requestId, String deliveryPersonId) async {
    await _firestore.collection(requestsCollection).doc(requestId).update({
      'status': 'delivering',
      'deliveryPersonId': deliveryPersonId,
      'startTime': FieldValue.serverTimestamp(),
    });
  }

  // ✅ 配達を完了する
  static Future<void> completeDelivery(String requestId) async {
    await _firestore.collection(requestsCollection).doc(requestId).update({
      'status': 'completed',
      'completedTime': FieldValue.serverTimestamp(),
    });
  }

  // 📊 配達統計を記録（任意）
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
        .where('status', isEqualTo: 'waiting')
        .where('priority', isEqualTo: 'high')
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
      print('位置情報取得エラー: $e');
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
    print('✅ 避難所データを作成しました');
  }
}