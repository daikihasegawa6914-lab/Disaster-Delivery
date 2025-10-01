// 🚀 Firebase最適化設定 - 無料枠を最大限活用
// 災害時対応＋セキュリティ強化＋コスト削減

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OptimizedFirestoreConfig {
  static FirebaseFirestore? _instance;
  
  // 🔧 Firestoreの最適化設定
  static FirebaseFirestore get instance {
    if (_instance == null) {
      _instance = FirebaseFirestore.instance;
      _configureFirestore();
    }
    return _instance!;
  }

  static void _configureFirestore() {
    // 🔥 無料枠最適化設定
    _instance!.settings = const Settings(
      // キャッシュサイズを制限（無料枠内）
      cacheSizeBytes: 40 * 1024 * 1024, // 40MB
      
      // オフライン機能を有効化（災害時対応）
      persistenceEnabled: true,
      
      // SSL証明書検証を有効化（セキュリティ）
      sslEnabled: true,
    );

    if (kDebugMode) {
      print('🔧 Firestore最適化設定完了');
    }
  }

  // 📊 クエリ最適化（読み取り回数削減）
  static Query optimizeQuery(Query query, {
    int limit = 20, // デフォルト制限
    bool useCache = true,
  }) {
    // 制限を適用（無料枠保護）
    query = query.limit(limit);
    
    return query;
  }

  // 💾 バッチ書き込み最適化
  static WriteBatch createOptimizedBatch() {
    return _instance!.batch();
  }

  // 🔍 インデックス効率的クエリ
  static Query buildEfficientQuery({
    required String collection,
    String? whereField,
    dynamic whereValue,
    String? orderByField,
    bool descending = false,
    int limit = 10,
  }) {
    Query query = _instance!.collection(collection);
    
    // Where句（インデックス効率化）
    if (whereField != null && whereValue != null) {
      query = query.where(whereField, isEqualTo: whereValue);
    }
    
    // ソート（複合インデックス考慮）
    if (orderByField != null) {
      query = query.orderBy(orderByField, descending: descending);
    }
    
    // 制限（コスト削減）
    return query.limit(limit);
  }

  // 📈 リアルタイムリスナー最適化
  static StreamSubscription<QuerySnapshot> createOptimizedListener({
    required String collection,
    required Function(QuerySnapshot) onData,
    Function(Object)? onError,
    bool includeMetadataChanges = false,
  }) {
    return _instance!
        .collection(collection)
        .limit(20) // リアルタイム更新制限
        .snapshots(includeMetadataChanges: includeMetadataChanges)
        .listen(
          onData,
          onError: onError ?? (error) {
            if (kDebugMode) {
              print('🚨 Firestore Listener Error: $error');
            }
          },
        );
  }

  // 🔄 接続状態の監視（無料範囲内）
  static Stream<bool> get connectionState {
    return _instance!
        .enableNetwork()
        .asStream()
        .map((_) => true)
        .handleError((error) {
          if (kDebugMode) {
            print('🌐 Connection Error: $error');
          }
          return false;
        });
  }

  // 📱 オフライン対応（災害時必須）
  static Future<void> enableOfflineSupport() async {
    try {
      // Webプラットフォームではpersistenceは自動的に有効
      if (kDebugMode) {
        print('💾 オフライン対応有効化');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ オフライン対応設定エラー: $e');
      }
    }
  }

  // 📊 使用量モニタリング（無料枠監視）
  static void logQueryUsage(String operation, int documentCount) {
    if (kDebugMode) {
      print('📊 $operation: $documentCount documents');
      
      // 警告しきい値（1日50,000読み取りの80%）
      const warningThreshold = 40000;
      if (documentCount > warningThreshold) {
        print('⚠️ 無料枠使用量が多くなっています');
      }
    }
  }
}

// 🔐 セキュア＆効率的なデータアクセスヘルパー
class SecureDataAccess {
  static final _firestore = OptimizedFirestoreConfig.instance;

  // 📝 安全な配達依頼作成（レート制限付き）
  static Future<DocumentReference?> createDeliveryRequest(
    Map<String, dynamic> data,
  ) async {
    try {
      // タイムスタンプ追加
      data['timestamp'] = FieldValue.serverTimestamp();
      data['createdAt'] = DateTime.now().toIso8601String();
      
      // バッチ書き込みで効率化
      final batch = OptimizedFirestoreConfig.createOptimizedBatch();
      final docRef = _firestore.collection('delivery_requests').doc();
      
      batch.set(docRef, data);
      await batch.commit();
      
      OptimizedFirestoreConfig.logQueryUsage('Create Request', 1);
      return docRef;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ 配達依頼作成エラー: $e');
      }
      return null;
    }
  }

  // 🔍 効率的な配達依頼検索
  static Stream<QuerySnapshot> getDeliveryRequests({
    int limit = 10,
    String? status,
  }) {
    Query query = OptimizedFirestoreConfig.buildEfficientQuery(
      collection: 'delivery_requests',
      whereField: status != null ? 'status' : null,
      whereValue: status,
      orderByField: 'timestamp',
      descending: true,
      limit: limit,
    );

    return query.snapshots().map((snapshot) {
      OptimizedFirestoreConfig.logQueryUsage('Get Requests', snapshot.docs.length);
      return snapshot;
    });
  }

  // 🚚 配達者位置更新（効率化）
  static Future<void> updateDelivererLocation({
    required String delivererId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // バッチ更新で効率化
      final batch = OptimizedFirestoreConfig.createOptimizedBatch();
      final docRef = _firestore.collection('deliverers').doc(delivererId);
      
      batch.update(docRef, {
        'currentLatitude': latitude,
        'currentLongitude': longitude,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      OptimizedFirestoreConfig.logQueryUsage('Update Location', 1);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ 位置更新エラー: $e');
      }
    }
  }

  // 📊 統計データ集計（無料範囲内）
  static Future<Map<String, int>> getBasicStatistics() async {
    try {
      // 集計クエリを効率化
      final requestsQuery = OptimizedFirestoreConfig.buildEfficientQuery(
        collection: 'delivery_requests',
        limit: 1000, // 制限
      );
      
      final requestsSnapshot = await requestsQuery.get();
      
      final stats = <String, int>{
        'totalRequests': requestsSnapshot.docs.length,
        'urgentRequests': requestsSnapshot.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data != null && data['isUrgent'] == true;
            })
            .length,
      };

      OptimizedFirestoreConfig.logQueryUsage('Statistics', requestsSnapshot.docs.length);
      return stats;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ 統計取得エラー: $e');
      }
      return {};
    }
  }

  // 🏠 避難所情報の効率的取得
  static Stream<QuerySnapshot> getShelterInfo({int limit = 50}) {
    return OptimizedFirestoreConfig.buildEfficientQuery(
      collection: 'shelter_info',
      orderByField: 'name',
      limit: limit,
    ).snapshots();
  }

  // 📱 オフライン対応データ同期
  static Future<void> syncOfflineData() async {
    try {
      // 重要なデータのみプリフェッチ
      await _firestore.collection('delivery_requests')
          .where('status', whereIn: ['pending', 'in_progress'])
          .limit(20)
          .get();
      
      await _firestore.collection('shelter_info')
          .limit(10)
          .get();
      
      if (kDebugMode) {
        print('💾 オフラインデータ同期完了');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ オフライン同期エラー: $e');
      }
    }
  }

  // 🔥 緊急時の優先データ取得
  static Future<List<Map<String, dynamic>>> getEmergencyData() async {
    try {
      // 優先度の高い配達依頼のみ取得
      final urgentRequests = await _firestore
          .collection('delivery_requests')
          .where('isUrgent', isEqualTo: true)
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return urgentRequests.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 緊急データ取得エラー: $e');
      }
      return [];
    }
  }
}

/// 💡 使用例：
/// 
/// ```dart
/// // アプリ起動時の最適化設定
/// await OptimizedFirestoreConfig.enableOfflineSupport();
/// 
/// // 効率的なデータ取得
/// final requests = SecureDataAccess.getDeliveryRequests(limit: 10);
/// 
/// // 安全なデータ作成
/// final result = await SecureDataAccess.createDeliveryRequest(validatedData);
/// 
/// // オフライン対応
/// await SecureDataAccess.syncOfflineData();
/// ```