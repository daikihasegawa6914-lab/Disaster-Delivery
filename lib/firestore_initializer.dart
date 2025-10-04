// ignore_for_file: avoid_print
// 🔧 Deprecated test seeding utility (保持理由: 参考用サンプル). 本番ビルドでは未使用。
import 'package:cloud_firestore/cloud_firestore.dart';

// 👶 このファイルはFirestoreの初期化やテストデータ作成用のロジックです。
// - 開発時にサンプルデータを簡単に投入できるように設計されています。
// - 本番環境では通常無効化されるか、別の設定が使用されます。

// 🗄️ Firestoreデータベース初期化とテストデータ作成
class FirestoreInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🏗️ データベース初期化（簡素版）
  static Future<void> initializeDatabase() async {
    try {
      // 既存の requests コレクションにテストデータを追加（もし空であれば）
      await _createSimpleTestData();
      
  // 初期化ログ (デモ用途) ※ 本番未使用
  // print('🏗️ [INFO] 簡易データベース初期化完了');
    } catch (e) {
  // print('🏗️ [INFO] データベースは既に存在するか、オフライン: $e');
    }
  }

  // 📦 シンプルなテストデータ作成
  static Future<void> _createSimpleTestData() async {
    // まず requests コレクションをチェック
    final existingRequests = await _firestore.collection('requests').limit(1).get();
    
    if (existingRequests.docs.isEmpty) {
      // requests コレクションが空の場合のみテストデータを追加
      await _firestore.collection('requests').doc('test_req_001').set({
        'item': '食料・水',
        'location': '品川区避難所',
        'latitude': 35.6284,
        'longitude': 139.7408,
        'status': 'waiting',
        'priority': 'high',
        'timestamp': FieldValue.serverTimestamp(),
        'requesterName': 'テスト 太郎',
        'notes': 'テスト用配達要請です',
      });
    }
  }

  // 🧪 テスト用配達員データ作成
  static Future<void> createTestDeliveryPerson(String uid, String name, String phone) async {
    await _firestore.collection('delivery_persons').doc(uid).set({
      'uid': uid,
      'name': name,
      'phone': phone,
      'vehicleType': '🚗 自動車',
      'vehicleNumber': '品川 500 あ 1234',
      'profileImageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'rating': 5.0,
      'deliveryCount': 0,
      'currentLocation': {
        'latitude': 35.6580,
        'longitude': 139.7016,
      },
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }
}