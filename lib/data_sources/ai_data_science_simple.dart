import 'package:geolocator/geolocator.dart';

/// 🤖 災害配送効率計算システム
/// 
/// 基本的な数学計算で配送効率を予測するシンプルなシステム
/// 大学生でも理解しやすい明確な計算方法を使用
class DisasterDeliveryAI {
  
  /// 📊 配送効率予測 (基本的な重み付け計算)
  static DeliveryPrediction predictDeliverySuccess({
    required List<DeliveryRequest> requests,
    required WeatherCondition weather,
    required TrafficCondition traffic,
    required Position delivererLocation,
  }) {
    
    // 🎯 基本効率スコア（開始値：80%）
    double score = 80.0;
    List<String> factors = [];
    
    // 🌦️ 天候による影響（シンプルな減点方式）
    String weatherCondition = weather.description ?? 'unknown';
    if (weatherCondition.contains('雨') || weatherCondition.contains('rain')) {
      score -= 10.0;
      factors.add('雨天により10%減点');
    } else if (weatherCondition.contains('大雨') || weatherCondition.contains('heavy')) {
      score -= 20.0;
      factors.add('大雨により20%減点');
    }
    
    // 🚗 交通状況による影響
    String trafficLevel = traffic.description ?? 'normal';
    if (trafficLevel.contains('渋滞') || trafficLevel.contains('congestion')) {
      score -= 15.0;
      factors.add('渋滞により15%減点');
    }
    
    // 📍 距離による影響（シンプルな距離計算）
    double totalDistance = _calculateTotalDistance(requests, delivererLocation);
    if (totalDistance > 50.0) {
      score -= 10.0;
      factors.add('長距離配送により10%減点');
    }
    
    // 📦 配送件数による影響
    if (requests.length > 10) {
      score -= 5.0;
      factors.add('多件数配送により5%減点');
    }
    
    // 🎯 最終スコア計算（最低10%は保証）
    double finalScore = score.clamp(10.0, 100.0);
    
    // 📋 シンプルな提案生成
    List<String> suggestions = [];
    if (finalScore < 70) {
      suggestions.add('天候改善を待つか、ルート変更を検討してください');
    }
    if (requests.length > 8) {
      suggestions.add('配送件数を分割することを推奨します');
    }
    
    return DeliveryPrediction(
      successProbability: finalScore,
      estimatedTimeHours: _calculateSimpleTime(requests.length),
      riskFactors: factors,
      optimizationSuggestions: suggestions.map((s) => OptimizationSuggestion(
        suggestion: s,
        impact: 'medium',
        priority: 1,
      )).toList(),
      routeEfficiency: finalScore / 100,
    );
  }
  
  /// 🛣️ シンプルなルート最適化
  static OptimizedRoute optimizeDeliveryRoute({
    required Position startLocation,
    required List<DeliveryRequest> requests,
    required TrafficCondition traffic,
  }) {
    
    // 📍 最寄り優先の単純なアルゴリズム
    List<DeliveryRequest> sortedRequests = List.from(requests);
    sortedRequests.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(
        startLocation.latitude, startLocation.longitude,
        a.latitude, a.longitude,
      );
      double distanceB = Geolocator.distanceBetween(
        startLocation.latitude, startLocation.longitude,
        b.latitude, b.longitude,
      );
      return distanceA.compareTo(distanceB);
    });
    
    // 📊 基本的な効率計算
    double totalDistance = _calculateTotalDistance(sortedRequests, startLocation);
    double estimatedTime = _calculateSimpleTime(sortedRequests.length);
    
    return OptimizedRoute(
      orderedDeliveries: sortedRequests,
      totalDistance: totalDistance,
      estimatedDuration: estimatedTime,
      fuelSavings: totalDistance * 0.1, // 10%燃費改善と仮定
      efficiency: _calculateRouteEfficiency(sortedRequests, startLocation),
    );
  }
  
  /// 📈 需要予測（シンプルな過去データ分析）
  static DemandForecast forecastDemand({
    required String area,
    required DateTime timeWindow,
    required List<HistoricalDelivery> historicalData,
  }) {
    
    // 🗓️ 過去の同じ時間帯の平均を計算
    List<HistoricalDelivery> similarTimeData = historicalData.where((data) {
      return data.timestamp.hour == timeWindow.hour &&
             data.area == area;
    }).toList();
    
    if (similarTimeData.isEmpty) {
      return DemandForecast(
        expectedRequests: 5, // デフォルト値
        confidenceLevel: 50.0,
        peakHours: [12, 18], // 昼と夕方
        demandDistribution: {'normal': 5},
        recommendations: ['過去データが不足しています'],
      );
    }
    
    // 📊 平均需要計算
    double averageDemand = similarTimeData
        .map((d) => d.requestCount)
        .reduce((a, b) => a + b) / similarTimeData.length;
    
    return DemandForecast(
      expectedRequests: averageDemand.round(),
      confidenceLevel: 75.0,
      peakHours: [12, 18],
      demandDistribution: {'normal': averageDemand.round()},
      recommendations: ['平均的な需要が予測されます'],
    );
  }
  
  /// 📈 簡単な配送時間計算
  static double _calculateSimpleTime(int requestCount) {
    // 基本：1件あたり30分 + 移動時間
    return (requestCount * 0.5) + 1.0; // 時間単位
  }
  
  /// 📊 基本的な距離計算
  static double _calculateTotalDistance(List<DeliveryRequest> requests, Position start) {
    if (requests.isEmpty) return 0.0;
    
    double totalDistance = 0.0;
    Position currentPos = start;
    
    // 各配送先への直線距離を合計（実際のアプリではより精密に）
    for (var request in requests) {
      double distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        request.latitude,
        request.longitude,
      ) / 1000; // メートルをキロメートルに変換
      
      totalDistance += distance;
      currentPos = Position(
        latitude: request.latitude,
        longitude: request.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    
    return totalDistance;
  }
  
  /// 📊 ルート効率計算
  static double _calculateRouteEfficiency(List<DeliveryRequest> requests, Position start) {
    if (requests.isEmpty) return 1.0;
    
    double totalDistance = _calculateTotalDistance(requests, start);
    double directDistance = requests.length > 0 ? Geolocator.distanceBetween(
      start.latitude, start.longitude,
      requests.last.latitude, requests.last.longitude,
    ) / 1000 : 0.0;
    
    // 効率 = 直線距離 / 実際の距離（1に近いほど効率的）
    return directDistance > 0 ? (directDistance / totalDistance).clamp(0.0, 1.0) : 1.0;
  }
}

// 📋 データクラス定義（シンプル版）

class DeliveryPrediction {
  final double successProbability;
  final double estimatedTimeHours;
  final List<String> riskFactors;
  final List<OptimizationSuggestion> optimizationSuggestions;
  final double routeEfficiency;
  
  DeliveryPrediction({
    required this.successProbability,
    required this.estimatedTimeHours,
    required this.riskFactors,
    required this.optimizationSuggestions,
    required this.routeEfficiency,
  });
}

class OptimizationSuggestion {
  final String suggestion;
  final String impact;
  final int priority;
  
  OptimizationSuggestion({
    required this.suggestion,
    required this.impact,
    required this.priority,
  });
}

class OptimizedRoute {
  final List<DeliveryRequest> orderedDeliveries;
  final double totalDistance;
  final double estimatedDuration;
  final double fuelSavings;
  final double efficiency;
  
  OptimizedRoute({
    required this.orderedDeliveries,
    required this.totalDistance,
    required this.estimatedDuration,
    required this.fuelSavings,
    required this.efficiency,
  });
}

class DemandForecast {
  final int expectedRequests;
  final double confidenceLevel;
  final List<int> peakHours;
  final Map<String, int> demandDistribution;
  final List<String> recommendations;
  
  DemandForecast({
    required this.expectedRequests,
    required this.confidenceLevel,
    required this.peakHours,
    required this.demandDistribution,
    required this.recommendations,
  });
}

class DeliveryRequest {
  final double latitude;
  final double longitude;
  final String address;
  final String item;
  final int priority;
  
  DeliveryRequest({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.item,
    required this.priority,
  });
}

class WeatherCondition {
  final String? description;
  final double temperature;
  final double humidity;
  
  WeatherCondition({
    this.description,
    required this.temperature,
    required this.humidity,
  });
}

class TrafficCondition {
  final String? description;
  final double averageSpeed;
  
  TrafficCondition({
    this.description,
    required this.averageSpeed,
  });
}

class HistoricalDelivery {
  final DateTime timestamp;
  final String area;
  final int requestCount;
  
  HistoricalDelivery({
    required this.timestamp,
    required this.area,
    required this.requestCount,
  });
}