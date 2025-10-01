import 'package:geolocator/geolocator.dart';

/// 🗾 シンプルな災害情報取得サービス
/// 
/// 大学生でも理解しやすい基本的なAPI呼び出しのみ実装
/// 複雑な統合処理は削除し、必要最小限の機能に絞り込み
class SimpleDataService {
  
  /// 🌪️ 基本的な災害情報取得（気象庁風のダミーデータ）
  static Future<Map<String, dynamic>> getDisasterInfo() async {
    // 実際のAPIの代わりに、理解しやすいサンプルデータを返す
    await Future.delayed(Duration(seconds: 1)); // API呼び出しのシミュレーション
    
    try {
      // ダミーデータ（実際のアプリでは気象庁APIなどから取得）
      return {
        'status': 'success',
        'earthquakes': [
          {
            'magnitude': 4.2,
            'depth': 45,
            'location': '東京湾',
            'time': DateTime.now().toIso8601String(),
            'tsunami_risk': false,
          }
        ],
        'weather_alerts': [
          {
            'type': 'heavy_rain',
            'level': 'warning',
            'areas': ['東京23区', '神奈川県東部'],
            'issued_at': DateTime.now().toIso8601String(),
          }
        ],
        'traffic_info': [
          {
            'route': '首都高速道路',
            'condition': 'congestion',
            'delay_minutes': 15,
            'alternative_route': '一般道',
          },
          {
            'route': '国道1号',
            'condition': 'normal',
          }
        ],
        'source': '防災科学技術研究所',
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': '災害情報を取得できませんでした',
        'error': e.toString(),
      };
    }
  }
  
  /// 🏠 シンプルな避難所情報取得
  static Future<List<Map<String, dynamic>>> getShelterInfo(Position? userLocation) async {
    await Future.delayed(Duration(milliseconds: 800)); // API呼び出しのシミュレーション
    
    try {
      // 実際のアプリでは国土交通省のオープンデータAPIから取得
      List<Map<String, dynamic>> shelters = [
        {
          'id': 'shelter_001',
          'name': '中央区立明正小学校',
          'address': '東京都中央区新川2-13-4',
          'latitude': 35.6762,
          'longitude': 139.7640,
          'capacity': 500,
          'current_occupancy': 120,
          'available_space': 380,
          'has_medical': true,
          'has_food': true,
          'contact': '03-1234-5678',
          'distance_km': userLocation != null 
            ? _calculateDistance(userLocation, 35.6762, 139.7640) 
            : 0.0,
        },
        {
          'id': 'shelter_002',
          'name': '港区立芝小学校',
          'address': '東京都港区芝2-21-3',
          'latitude': 35.6565,
          'longitude': 139.7514,
          'capacity': 400,
          'current_occupancy': 80,
          'available_space': 320,
          'has_medical': true,
          'has_food': false,
          'contact': '03-2345-6789',
          'distance_km': userLocation != null 
            ? _calculateDistance(userLocation, 35.6565, 139.7514) 
            : 0.0,
        },
        {
          'id': 'shelter_003',
          'name': '品川区立第一中学校',
          'address': '東京都品川区北品川2-7-20',
          'latitude': 35.6197,
          'longitude': 139.7390,
          'capacity': 600,
          'current_occupancy': 200,
          'available_space': 400,
          'has_medical': false,
          'has_food': true,
          'contact': '03-3456-7890',
          'distance_km': userLocation != null 
            ? _calculateDistance(userLocation, 35.6197, 139.7390) 
            : 0.0,
        },
      ];
      
      // ユーザーの位置から近い順にソート
      if (userLocation != null) {
        shelters.sort((a, b) => 
          a['distance_km'].compareTo(b['distance_km']));
      }
      
      return shelters;
    } catch (e) {
      print('避難所情報取得エラー: $e');
      return [];
    }
  }
  
  /// 📊 基本的な配送効率分析
  static Map<String, dynamic> analyzeDeliveryEfficiency({
    required List<Map<String, dynamic>> shelterData,
    required Map<String, dynamic> disasterInfo,
  }) {
    
    try {
      // シンプルな効率計算
      int totalShelters = shelterData.length;
      int availableShelters = shelterData.where((shelter) => 
        (shelter['available_space'] as int) > 50).length;
      
      // 配送効率の基本計算
      double efficiency = totalShelters > 0 
        ? (availableShelters / totalShelters * 100) 
        : 0.0;
      
      // 災害レベルによる調整
      List<dynamic> alerts = disasterInfo['weather_alerts'] ?? [];
      if (alerts.isNotEmpty) {
        efficiency *= 0.8; // 警報発令時は20%効率低下
      }
      
      List<dynamic> earthquakes = disasterInfo['earthquakes'] ?? [];
      if (earthquakes.isNotEmpty) {
        double magnitude = earthquakes[0]['magnitude'] ?? 0.0;
        if (magnitude > 5.0) {
          efficiency *= 0.7; // 大きな地震時は30%効率低下
        }
      }
      
      return {
        'overall_efficiency': efficiency.clamp(0.0, 100.0),
        'available_shelters': availableShelters,
        'total_shelters': totalShelters,
        'risk_factors': _identifyRiskFactors(disasterInfo),
        'recommendations': _generateRecommendations(efficiency, shelterData),
        'analysis_time': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      return {
        'overall_efficiency': 50.0,
        'error': '分析中にエラーが発生しました',
        'analysis_time': DateTime.now().toIso8601String(),
      };
    }
  }
  
  /// 📍 距離計算（シンプルな直線距離）
  static double _calculateDistance(Position userPos, double lat, double lng) {
    return Geolocator.distanceBetween(
      userPos.latitude, userPos.longitude, lat, lng
    ) / 1000; // メートルをキロメートルに変換
  }
  
  /// ⚠️ リスク要因の特定
  static List<String> _identifyRiskFactors(Map<String, dynamic> disasterInfo) {
    List<String> risks = [];
    
    List<dynamic> alerts = disasterInfo['weather_alerts'] ?? [];
    for (var alert in alerts) {
      if (alert['level'] == 'warning') {
        risks.add('${alert['type']}警報発令中');
      }
    }
    
    List<dynamic> earthquakes = disasterInfo['earthquakes'] ?? [];
    for (var eq in earthquakes) {
      if (eq['magnitude'] > 4.0) {
        risks.add('マグニチュード${eq['magnitude']}の地震発生');
      }
    }
    
    List<dynamic> traffic = disasterInfo['traffic_info'] ?? [];
    for (var t in traffic) {
      if (t['condition'] == 'congestion') {
        risks.add('${t['route']}で交通渋滞');
      }
    }
    
    return risks;
  }
  
  /// 💡 配送提案の生成
  static List<String> _generateRecommendations(double efficiency, List<Map<String, dynamic>> shelters) {
    List<String> recommendations = [];
    
    if (efficiency < 60) {
      recommendations.add('配送ルートの見直しを推奨');
      recommendations.add('より効率的な避難所への配送を検討');
    }
    
    int fullShelters = shelters.where((s) => 
      (s['available_space'] as int) < 50).length;
    if (fullShelters > 0) {
      recommendations.add('$fullShelters箇所の避難所が満員に近い状態');
    }
    
    int medicalShelters = shelters.where((s) => 
      s['has_medical'] == true).length;
    if (medicalShelters > 0) {
      recommendations.add('$medicalShelters箇所で医療支援が可能');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('現在の配送計画は適切です');
    }
    
    return recommendations;
  }
}

/// 📊 シンプルなデータ型定義
class SimpleWeatherCondition {
  final String description;
  final double temperature;
  final double humidity;
  
  SimpleWeatherCondition({
    required this.description,
    required this.temperature,
    required this.humidity,
  });
}

class SimpleTrafficCondition {
  final String description;
  final double averageSpeed;
  
  SimpleTrafficCondition({
    required this.description,
    required this.averageSpeed,
  });
}