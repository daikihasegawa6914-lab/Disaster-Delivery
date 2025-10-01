import 'package:cloud_firestore/cloud_firestore.dart';

// 👶 簡単に言うと：「テストデータを簡単に作る専門家」
class TestDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🧪 テストデータを一括作成
  static Future<void> createTestData() async {
    print('🧪 テストデータ作成開始...');
    
    try {
      // 既存のテストデータを確認
      final existingData = await _firestore.collection('requests').get();
      if (existingData.docs.isNotEmpty) {
        print('⚠️ 既にデータが存在します。削除してから作成しますか？');
        return;
      }
      
      // テストデータ1: 緊急要請
      await _createTestRequest(
        item: '薬（血圧の薬）',
        name: '佐藤花子',
        latitude: 35.6895,
        longitude: 139.6917,
        priority: 'high',
        phone: '090-1111-2222',
      );
      
      // 少し待機（timestamp の違いを作るため）
      await Future.delayed(const Duration(seconds: 1));
      
      // テストデータ2: 通常要請
      await _createTestRequest(
        item: 'パン 3個',
        name: '山田次郎', 
        latitude: 35.6762,
        longitude: 139.6503,
        priority: 'medium',
        phone: '090-3333-4444',
      );
      
      await Future.delayed(const Duration(seconds: 1));
      
      // テストデータ3: 低優先度要請
      await _createTestRequest(
        item: 'お菓子',
        name: '鈴木三郎',
        latitude: 35.6635,
        longitude: 139.7514,
        priority: 'low',
        phone: null,
      );
      
      print('✅ テストデータ作成完了！');
      
    } catch (e) {
      print('❌ テストデータ作成エラー: $e');
    }
  }
  
  // 📄 個別のテスト要請を作成
  static Future<void> _createTestRequest({
    required String item,
    required String name,
    required double latitude,
    required double longitude,
    required String priority,
    String? phone,
    String status = 'waiting',
    String? deliveryPersonId,
  }) async {
    
    final data = {
      'item': item,
      'name': name,
      'location': GeoPoint(latitude, longitude),
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
      'priority': priority,
      'phone': phone,
    };
    
    // 配達中または完了の場合は配達員IDを追加
    if (deliveryPersonId != null) {
      data['deliveryPersonId'] = deliveryPersonId;
    }
    
    // 配達開始・完了時刻を追加
    if (status == 'delivering') {
      data['startTime'] = FieldValue.serverTimestamp();
    } else if (status == 'completed') {
      data['startTime'] = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1)));
      data['completedTime'] = FieldValue.serverTimestamp();
    }
    
    await _firestore.collection('requests').add(data);
    print('📝 テスト要請作成: $item ($name)');
  }
  
  // 🗑️ 全てのテストデータを削除
  static Future<void> clearAllTestData() async {
    print('🗑️ テストデータ削除開始...');
    
    try {
      // requests コレクションのデータを削除
      final requestsSnapshot = await _firestore.collection('requests').get();
      for (final doc in requestsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // deliveries コレクションのデータを削除
      final deliveriesSnapshot = await _firestore.collection('deliveries').get();
      for (final doc in deliveriesSnapshot.docs) {
        await doc.reference.delete();
      }
      
      print('✅ 全てのテストデータを削除しました');
      
    } catch (e) {
      print('❌ テストデータ削除エラー: $e');
    }
  }
  
  // 📊 現在のデータ状況を確認
  static Future<void> checkDataStatus() async {
    try {
      final requestsSnapshot = await _firestore.collection('requests').get();
      final deliveriesSnapshot = await _firestore.collection('deliveries').get();
      
      print('📊 データ状況:');
      print('  requests: ${requestsSnapshot.docs.length}件');
      print('  deliveries: ${deliveriesSnapshot.docs.length}件');
      
      // 状態別の件数
      final waiting = requestsSnapshot.docs.where((doc) => doc.data()['status'] == 'waiting').length;
      final delivering = requestsSnapshot.docs.where((doc) => doc.data()['status'] == 'delivering').length;
      final completed = requestsSnapshot.docs.where((doc) => doc.data()['status'] == 'completed').length;
      
      print('  ⏳ 待機中: ${waiting}件');
      print('  🚚 配達中: ${delivering}件');
      print('  ✅ 完了: ${completed}件');
      
    } catch (e) {
      print('❌ データ状況確認エラー: $e');
    }
  }
}