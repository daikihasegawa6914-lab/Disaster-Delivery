// 🛡️ セキュリティ強化エラーハンドリング - 機密情報保護システム
// 無料で実装できる包括的エラー対策

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

// 🚨 セキュリティレベル定義
enum SecurityLevel {
  info,    // 情報
  warning, // 警告
  error,   // エラー
  critical // 重大
}

class SecureErrorHandler {
  // 📝 エラーログの安全な管理（メモリ使用量制限）
  static final List<Map<String, dynamic>> _errorLogs = [];
  static const int _maxLogEntries = 50; // メモリ節約

  // 🔐 機密情報を含むエラーメッセージの検出パターン
  static final List<RegExp> _sensitivePatterns = [
    RegExp(r'AIza[A-Za-z0-9_-]{35}'), // Google API Key
    RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b'), // クレジットカード
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), // メール
    RegExp(r'\b0[789]0-\d{4}-\d{4}\b'), // 電話番号
    RegExp(r'password.*[:=]\s*\S+', caseSensitive: false), // パスワード
    RegExp(r'token.*[:=]\s*\S+', caseSensitive: false), // トークン
    RegExp(r'secret.*[:=]\s*\S+', caseSensitive: false), // シークレット
  ];

  // 🧹 機密情報を安全にマスクする
  static String _sanitizeErrorMessage(String message) {
    String sanitized = message;
    
    for (final pattern in _sensitivePatterns) {
      sanitized = sanitized.replaceAll(pattern, '[機密情報_削除]');
    }
    
    return sanitized;
  }

  // 📊 安全なエラーログ記録
  static void logSecureError({
    required String operation,
    required dynamic error,
    StackTrace? stackTrace,
    SecurityLevel level = SecurityLevel.error,
    Map<String, dynamic>? context,
  }) {
    final timestamp = DateTime.now();
    final sanitizedMessage = _sanitizeErrorMessage(error.toString());
    
    final logEntry = {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'operation': operation,
      'message': sanitizedMessage,
      'context': context ?? {},
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    };

    // デバッグモードでのみスタックトレースを含める（制限付き）
    if (kDebugMode && stackTrace != null) {
      final stackLines = stackTrace.toString().split('\n');
      logEntry['stackTrace'] = stackLines.take(3).join('\n'); // 最初の3行のみ
    }

    _errorLogs.add(logEntry);
    
    // メモリ使用量制限
    if (_errorLogs.length > _maxLogEntries) {
      _errorLogs.removeAt(0);
    }

    // コンソール出力（開発時のみ）
    if (kDebugMode) {
      print('🔒 [${level.name.toUpperCase()}] $operation: $sanitizedMessage');
    }
  }

  // 🔍 エラーログの安全な取得
  static List<Map<String, dynamic>> getErrorLogs({
    SecurityLevel? level,
    String? operation,
    int? lastHours,
  }) {
    var filteredLogs = List<Map<String, dynamic>>.from(_errorLogs);

    if (level != null) {
      filteredLogs = filteredLogs
          .where((log) => log['level'] == level.name)
          .toList();
    }

    if (operation != null) {
      filteredLogs = filteredLogs
          .where((log) => log['operation'].toString().contains(operation))
          .toList();
    }

    if (lastHours != null) {
      final cutoff = DateTime.now().subtract(Duration(hours: lastHours));
      filteredLogs = filteredLogs
          .where((log) => DateTime.parse(log['timestamp']).isAfter(cutoff))
          .toList();
    }

    return filteredLogs;
  }

  // 🚨 アプリケーション全体のエラーハンドラー設定
  static void setupGlobalErrorHandling() {
    // Flutter フレームワークエラー
    FlutterError.onError = (FlutterErrorDetails details) {
      logSecureError(
        operation: 'Flutter Framework',
        error: details.exception,
        stackTrace: details.stack,
        level: SecurityLevel.error,
        context: {
          'library': details.library ?? 'unknown',
        },
      );
    };

    // 非同期エラー（プラットフォーム依存の処理）
    PlatformDispatcher.instance.onError = (error, stack) {
      logSecureError(
        operation: 'Async Operation',
        error: error,
        stackTrace: stack,
        level: SecurityLevel.critical,
      );
      return true;
    };
  }

  // 🔄 安全なTry-Catch ヘルパー関数
  static Future<T?> executeSecurely<T>({
    required String operation,
    required Future<T> Function() action,
    T? fallback,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      logSecureError(
        operation: operation,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );
      return fallback;
    }
  }

  // 🌐 ネットワークエラーの詳細ハンドリング
  static String getNetworkErrorMessage(dynamic error) {
    final sanitizedError = _sanitizeErrorMessage(error.toString());
    
    if (sanitizedError.contains('SocketException')) {
      return '🌐 インターネット接続を確認してください';
    } else if (sanitizedError.contains('TimeoutException')) {
      return '⏰ 接続がタイムアウトしました。再試行してください';
    } else if (sanitizedError.contains('HandshakeException')) {
      return '🔒 セキュリティ証明書の問題です';
    } else if (sanitizedError.contains('permission-denied')) {
      return '🚫 アクセス権限がありません';
    } else if (sanitizedError.contains('not-found')) {
      return '📭 データが見つかりません';
    } else if (sanitizedError.contains('unavailable')) {
      return '🚧 サービスが一時的に利用できません';
    } else {
      return '❌ 予期しないエラーが発生しました';
    }
  }

  // 📈 エラー統計の取得（無料範囲内）
  static Map<String, int> getErrorStatistics() {
    final stats = <String, int>{};
    
    for (final log in _errorLogs) {
      final level = log['level'] as String;
      stats[level] = (stats[level] ?? 0) + 1;
    }
    
    return stats;
  }

  // 🧽 古いログの削除（メモリ節約）
  static void clearOldLogs({int? keepLastHours}) {
    if (keepLastHours != null) {
      final cutoff = DateTime.now().subtract(Duration(hours: keepLastHours));
      _errorLogs.removeWhere(
        (log) => DateTime.parse(log['timestamp']).isBefore(cutoff)
      );
    } else {
      _errorLogs.clear();
    }
  }

  // 🔍 セキュリティ異常の検出
  static bool detectSecurityAnomaly() {
    final recentErrors = getErrorLogs(lastHours: 1);
    final criticalErrors = recentErrors
        .where((log) => log['level'] == SecurityLevel.critical.name)
        .length;
    
    // 1時間に3回以上の重大エラーは異常とみなす
    return criticalErrors >= 3;
  }

  // 🚨 災害時の緊急モード検出
  static bool isEmergencyMode() {
    final recentErrors = getErrorLogs(lastHours: 24);
    final networkErrors = recentErrors
        .where((log) => log['message'].toString().contains('SocketException'))
        .length;
    
    // 24時間で10回以上のネットワークエラーは災害時の可能性
    return networkErrors >= 10;
  }

  // 📱 ユーザーフレンドリーなエラー表示
  static String getUserFriendlyMessage(dynamic error, {String? operation}) {
    final baseMessage = getNetworkErrorMessage(error);
    
    if (isEmergencyMode()) {
      return '$baseMessage\n\n🚨 災害時モード: オフライン機能を利用してください';
    }
    
    return baseMessage;
  }

  // 🔄 自動復旧試行
  static Future<T?> executeWithRetry<T>({
    required String operation,
    required Future<T> Function() action,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await action();
      } catch (error) {
        logSecureError(
          operation: operation,
          error: 'Attempt $attempt failed: $error',
          level: attempt == maxRetries ? SecurityLevel.error : SecurityLevel.warning,
        );
        
        if (attempt < maxRetries) {
          await Future.delayed(delay * attempt); // 段階的な遅延
        }
      }
    }
    return null;
  }
}

/// 💡 使用例：
/// 
/// ```dart
/// // アプリ起動時
/// SecureErrorHandler.setupGlobalErrorHandling();
/// 
/// // データベース操作時
/// final result = await SecureErrorHandler.executeSecurely(
///   operation: 'Save Delivery Request',
///   action: () => saveToFirestore(data),
///   fallback: null,
///   context: {'userId': 'anonymous'},
/// );
/// 
/// // リトライ付き操作
/// final data = await SecureErrorHandler.executeWithRetry(
///   operation: 'Fetch Delivery Requests',
///   action: () => fetchFromFirestore(),
/// );
/// 
/// // ユーザーエラー表示
/// final userMessage = SecureErrorHandler.getUserFriendlyMessage(error);
/// showSnackBar(userMessage);
/// ```