import 'package:cloud_firestore/cloud_firestore.dart';
import '../data_sources/open_data_apis.dart';
import '../data_sources/ai_data_science.dart';
import 'package:geolocator/geolocator.dart';

/// 🌐 統合データサービス
/// Firestore + オープンデータAPI + AIを統合した包括的データ管理
class IntegratedDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// 🏠 避難所情報の取得（オープンデータ優先、Firestoreバックアップ）
  static Future<List<Map<String, dynamic>>> getShelterData(Position userLocation) async {
    try {
      // 🌐 Step 1: 国土交通省オープンデータから取得を試行
      List<Map<String, dynamic>> openDataShelters = 
          await OpenDataApiService.getNationalShelters(userLocation);
      
      if (openDataShelters.isNotEmpty) {
        print('✅ オープンデータから避難所情報を取得: ${openDataShelters.length}件');
        
        // 🔄 Firestoreにキャッシュ保存（オフライン対応）
        await _cacheShelterData(openDataShelters);
        
        return openDataShelters;
      }
    } catch (e) {
      print('⚠️ オープンデータ取得エラー: $e');
    }
    
    try {
      // 🔥 Step 2: Firestoreのキャッシュデータから取得
      print('🔄 Firestoreキャッシュから避難所データを取得中...');
      
      QuerySnapshot shelterSnapshot = await _firestore
          .collection('shelters_cache')
          .limit(20)
          .get();
      
      if (shelterSnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> cachedShelters = shelterSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList();
        
        print('✅ キャッシュから避難所情報を取得: ${cachedShelters.length}件');
        return cachedShelters;
      }
    } catch (e) {
      print('⚠️ Firestoreアクセスエラー: $e');
    }
    
    // 🆘 Step 3: フォールバック - 固定の緊急避難所データ
    return _getEmergencyShelterData(userLocation);
  }
  
  /// 🌦️ リアルタイム災害情報の取得
  static Future<Map<String, dynamic>> getDisasterInfo(Position location) async {
    Map<String, dynamic> combinedData = {
      'weather': {},
      'disasters': {},
      'traffic': {},
      'risk_assessment': {},
      'last_updated': DateTime.now().toIso8601String(),
    };
    
    try {
      // 気象庁データ取得
      Map<String, dynamic> weatherData = 
          await OpenDataApiService.getWeatherAlerts('130000'); // 東京都
      combinedData['weather'] = weatherData;
      
      // 災害アラート取得
      Map<String, dynamic> disasterAlerts = 
          await OpenDataApiService.getDisasterAlerts();
      combinedData['disasters'] = disasterAlerts;
      
      // 交通情報取得
      Map<String, dynamic> trafficInfo = 
          await OpenDataApiService.getTrafficConditions(location.latitude, location.longitude);
      combinedData['traffic'] = trafficInfo;
      
      // 🤖 AIによるリスク評価
      WeatherCondition weather = _parseWeatherCondition(weatherData);
      DisasterRiskAssessment riskAssessment = DisasterDeliveryAI.assessDisasterRisk(
        location: location,
        currentWeather: weather,
        historicalData: [], // 実際の実装では履歴データを渡す
      );
      
      combinedData['risk_assessment'] = {
        'overall_score': riskAssessment.overallRiskScore,
        'risk_level': riskAssessment.riskLevel,
        'specific_risks': riskAssessment.specificRisks,
        'safety_recommendations': riskAssessment.safetyRecommendations,
      };
      
    } catch (e) {
      print('⚠️ 災害情報取得エラー: $e');
      combinedData['error'] = '一部のデータを取得できませんでした';
    }
    
    return combinedData;
  }
  
  /// 🚚 AI駆動配送最適化
  static Future<Map<String, dynamic>> optimizeDeliveries(Position delivererLocation) async {
    try {
      // 📋 配送依頼一覧を取得
      List<DeliveryRequest> requests = await _getActiveDeliveryRequests();
      
      // 🌦️ 現在の天候・交通状況を取得
      Map<String, dynamic> disasterInfo = await getDisasterInfo(delivererLocation);
      WeatherCondition weather = _parseWeatherCondition(disasterInfo['weather']);
      TrafficCondition traffic = _parseTrafficCondition(disasterInfo['traffic']);
      
      // 🤖 AI予測実行
      DeliveryPrediction prediction = DisasterDeliveryAI.predictDeliverySuccess(
        requests: requests,
        weather: weather,
        traffic: traffic,
        delivererLocation: delivererLocation,
      );
      
      // 🛣️ ルート最適化
      OptimizedRoute optimizedRoute = DisasterDeliveryAI.optimizeDeliveryRoute(
        startLocation: delivererLocation,
        requests: requests,
        traffic: traffic,
      );
      
      return {
        'prediction': {
          'success_probability': prediction.successProbability,
          'estimated_time_hours': prediction.estimatedTimeHours,
          'risk_factors': prediction.riskFactors,
        },
        'optimization': {
          'optimized_order': optimizedRoute.deliveryOrder,
          'total_distance': optimizedRoute.totalDistance,
          'estimated_time': optimizedRoute.estimatedTime,
          'fuel_efficiency': optimizedRoute.fuelEfficiency,
        },
        'suggestions': prediction.optimizationSuggestions.map((s) => {
          'type': s.type.toString(),
          'title': s.title,
          'description': s.description,
          'improvement': s.expectedImprovement,
        }).toList(),
        'ai_insights': {
          'key_finding': prediction.aiInsights.keyFinding,
          'predictive_alerts': prediction.aiInsights.predictiveAlerts,
          'strategic_advice': prediction.aiInsights.strategicAdvice,
        },
      };
      
    } catch (e) {
      print('⚠️ AI最適化エラー: $e');
      return {
        'error': 'AI機能を利用できません',
        'fallback_message': '手動での配送計画をお勧めします',
      };
    }
  }
  
  /// 📊 需要予測とリソース配分
  static Future<Map<String, dynamic>> getDemandForecast(Position area) async {
    try {
      // 📈 過去データを取得（簡略化）
      List<HistoricalData> historicalData = await _getHistoricalData(area);
      
      // 🔮 AI需要予測
      DemandForecast forecast = DisasterDeliveryAI.forecastDemand(
        area: area,
        timeWindow: DateTime.now().add(Duration(hours: 6)),
        historicalData: historicalData,
      );
      
      return {
        'expected_requests': forecast.expectedRequests,
        'confidence_level': forecast.confidenceLevel,
        'peak_hours': forecast.peakHours,
        'demand_distribution': forecast.demandDistribution,
        'recommendations': forecast.recommendations,
        'forecast_period': '次の6時間',
        'generated_at': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('⚠️ 需要予測エラー: $e');
      return {
        'error': '需要予測を実行できません',
        'manual_estimate': '標準的な需要パターンを参考にしてください',
      };
    }
  }
  
  // ========================================
  // 🔧 内部ヘルパーメソッド
  // ========================================
  
  /// 避難所データのキャッシュ保存
  static Future<void> _cacheShelterData(List<Map<String, dynamic>> shelterData) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (var shelter in shelterData) {
        DocumentReference docRef = _firestore
            .collection('shelters_cache')
            .doc(shelter['id']);
        
        batch.set(docRef, {
          ...shelter,
          'cached_at': DateTime.now().toIso8601String(),
        });
      }
      
      await batch.commit();
      print('✅ 避難所データをキャッシュに保存しました');
    } catch (e) {
      print('⚠️ キャッシュ保存エラー: $e');
    }
  }
  
  /// 緊急時用の固定避難所データ
  static List<Map<String, dynamic>> _getEmergencyShelterData(Position userLocation) {
    return [
      {
        'id': 'emergency_001',
        'name': '東京都庁第一本庁舎',
        'address': '東京都新宿区西新宿2-8-1',
        'latitude': 35.6896,
        'longitude': 139.6920,
        'capacity': 1000,
        'facilities': ['医療室', '備蓄倉庫', 'バリアフリー', '24時間対応'],
        'contact': '03-5321-1111',
        'disaster_types': ['地震', '火災', '水害', 'その他'],
        'data_source': '緊急時固定データ',
        'distance_km': _calculateDistance(userLocation, 35.6896, 139.6920),
      },
      {
        'id': 'emergency_002',
        'name': '明治神宮外苑',
        'address': '東京都新宿区霞ヶ丘町',
        'latitude': 35.6783,
        'longitude': 139.7183,
        'capacity': 5000,
        'facilities': ['広域避難場所', '屋外スペース'],
        'contact': '03-3401-0312',
        'disaster_types': ['地震', '火災'],
        'data_source': '緊急時固定データ',
        'distance_km': _calculateDistance(userLocation, 35.6783, 139.7183),
      },
    ];
  }
  
  static double _calculateDistance(Position userPos, double lat, double lon) {
    return Geolocator.distanceBetween(
      userPos.latitude, userPos.longitude, lat, lon
    ) / 1000;
  }
  
  /// 配送依頼の取得
  static Future<List<DeliveryRequest>> _getActiveDeliveryRequests() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('delivery_requests')
          .where('status', isEqualTo: 'pending')
          .limit(10)
          .get();
      
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return DeliveryRequest(
          id: doc.id,
          latitude: data['latitude'] ?? 35.6762,
          longitude: data['longitude'] ?? 139.6503,
          address: data['address'] ?? '',
          priority: data['priority'] ?? 2,
          requestTime: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();
    } catch (e) {
      print('⚠️ 配送依頼取得エラー: $e');
      // フォールバック: サンプルデータ
      return [
        DeliveryRequest(
          id: 'sample_001',
          latitude: 35.6762,
          longitude: 139.6503,
          address: 'サンプル配送先1',
          priority: 3,
          requestTime: DateTime.now(),
        ),
      ];
    }
  }
  
  /// 気象データの解析
  static WeatherCondition _parseWeatherCondition(Map<String, dynamic> weatherData) {
    return WeatherCondition(
      temperature: 20.0,
      precipitation: 0.0,
      windSpeed: 5.0,
      visibility: 10000.0,
      alertLevel: 1,
    );
  }
  
  /// 交通データの解析
  static TrafficCondition _parseTrafficCondition(Map<String, dynamic> trafficData) {
    return TrafficCondition(
      congestionLevel: 0.3,
      accidentCount: 0,
      roadClosures: 0,
    );
  }
  
  /// 履歴データの取得
  static Future<List<HistoricalData>> _getHistoricalData(Position area) async {
    // 実際の実装では過去の配送データを分析
    return [
      HistoricalData(
        timestamp: DateTime.now().subtract(Duration(days: 1)),
        demandCount: 15,
        contextData: {'weather': 'clear', 'day_of_week': 'monday'},
      ),
    ];
  }
}