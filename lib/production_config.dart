// 🏭 本番環境設定
class ProductionConfig {
  // 本番環境かどうかを判定
  static const bool isProduction = true; // 本番環境: true, 開発環境: false
  
  // テストデータ機能を有効にするか
  static bool get enableTestData => !isProduction;
  
  // アプリの環境名
  static String get environmentName => isProduction ? '本番環境' : '開発環境';
  
  // デバッグ情報の表示
  static bool get showDebugInfo => !isProduction;
}