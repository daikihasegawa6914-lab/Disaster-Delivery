# Copilot Instructions for Disaster Delivery App

## 🏗️ プロジェクト概要

このアプリは、災害時に避難所や被災者と配送ドライバーをつなぐ **Flutter 災害配送アプリ** です。Firebase を活用したリアルタイムデータ管理を特徴としています。

**主な特徴:**
- 8日間のハッカソンプロジェクト
- 初学者向けのコードベース（日本語コメント付き）
- セキュリティを最優先に設計

## 📁 アーキテクチャ構成

### コア構造
```
lib/
├── main.dart                    # アプリのエントリーポイント
├── main_screen.dart            # タブナビゲーション（DeliveryMapScreen, ShelterScreen）
├── models.dart                 # データモデル（DeliveryRequest, DeliveryPerson, Shelter）
├── services.dart               # Firebase & 位置情報サービス
├── security/                   # セキュリティレイヤー
│   ├── secure_error_handler.dart
│   ├── input_validator.dart
│   └── optimized_firestore.dart
├── delivery_map_screen.dart    # Google Maps で配送リクエストを表示
└── shelter_screen.dart         # 避難所情報
```

### データフローパターン
1. **Firebase ストリーム** → リアルタイムデータバインディング
2. **セキュリティレイヤー** → 入力検証とエラーサニタイズ
3. **位置情報サービス** → 配送ルートの GPS 統合
4. **状態管理** → `setState` を使用したシンプルな管理

## 🔥 Firebase 統合パターン

### Firestore コレクション
- `requests` - 配送リクエストとステータス管理
- `deliveries` - 完了した配送記録
- `shelters` - 避難所情報

### セキュリティルールの哲学
`firestore.rules` に記載:
- 東京エリアの座標検証（35-36°N, 139-140.5°E）
- 文字列のサニタイズ（インジェクション攻撃対策）
- レート制限（1分間に5リクエスト）
- 重要な災害データは読み取り専用

### サービスレイヤーパターン
`services.dart`:
```dart
// ストリームベースのリアルタイム更新
FirebaseService.getWaitingRequests()
FirebaseService.getMyDeliveries(deliveryPersonId)

// ステータス管理
FirebaseService.startDelivery(requestId, deliveryPersonId)
FirebaseService.completeDelivery(requestId)
```

## 🛡️ セキュリティ優先の開発

### 必須セキュリティレイヤー
すべての操作は `security/` モジュールを通過:
- **SecureErrorHandler**: エラーメッセージ内の機密データをサニタイズ
- **InputValidator**: Firebase 操作前にすべてのユーザー入力を検証
- **OptimizedFirestore**: オフラインサポートと接続最適化を管理

### エラーハンドリングパターン
```dart
// main.dart - グローバルエラーハンドリング設定
SecureErrorHandler.setupGlobalErrorHandling();
SecureErrorHandler.logSecureError(
  operation: '操作名',
  error: errorObject,
  level: SecurityLevel.error,
);
```

## 🗺️ Google Maps 統合

### 位置情報サービスパターン
```dart
// 現在地取得と権限処理
LocationService.getCurrentLocation()
LocationService.calculateDistance(from, to)

// 東京災害エリアの座標検証
isValidCoordinates(lat, lng) // 35-36°N, 139-140.5°E
```

## 🎯 開発ワークフロー

### セットアップコマンド
```bash
# Firebase 設定（最初に必要）
cp lib/firebase_options.dart.example lib/firebase_options.dart
# 実際の Firebase 設定値を編集

# 依存関係の取得
flutter pub get

# Firebase 接続で実行
flutter run
```

### Firebase ルールのテスト
```bash
# セキュリティルールのデプロイ
firebase deploy --only firestore:rules

# ローカルでルールをテスト
firebase emulators:start --only firestore
```

## 🌟 コード規約

### コメントスタイル
- **👶** 初学者向けの日本語説明
- **🛡️** セキュリティ関連コード
- **🔥** Firebase 操作
- **📍** 位置情報/マッピング機能

### モデルパターン
`models.dart` のモデルは以下の構造:
```dart
class DeliveryRequest {
  // Firestore からのファクトリコンストラクタ
  factory DeliveryRequest.fromFirestore(DocumentSnapshot doc)

  // Firestore 形式への変換メソッド
  Map<String, dynamic> toFirestore()

  // 不変の更新
  DeliveryRequest copyWith({...})

  // UI ヘルパーメソッド
  String get priorityColor  // 🔴🟡🟢
  String get statusIcon     // ⏳🚚✅
}
```

### ストリームベースの UI 更新
```dart
// リアルタイムデータバインディングパターン
StreamBuilder<List<DeliveryRequest>>(
  stream: FirebaseService.getWaitingRequests(),
  builder: (context, snapshot) {
    // ローディング、エラー、データ状態の処理
  },
)
```

## 🚨 重要な統合ポイント

### Firebase 設定
- プロジェクト ID: `disaster-delivery-app`
- 設定ファイル: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- Dart オプション: `lib/firebase_options.dart`（テンプレートは `.example` にあり）

### Google Maps API
- プラットフォーム固有の設定で API キーが必要
- 地図マーカーは配送リクエストのステータスを絵文字で表示
- 配送最適化のための距離計算

### 環境固有のパターン
- 開発: Firebase エミュレータを使用
- 本番: `production_config.dart` を使用
- エラーログ: モバイルパフォーマンスのためメモリ制限（最大50件）

## 🔄 状態管理アプローチ

**意図的にシンプル**: 複雑な状態管理の代わりに `setState` と `StreamBuilder` を使用
- 8日間の開発期間に適した設計
- 単一開発者向けの簡易デバッグ
- Firebase ストリームによるリアルタイム更新

## 🎨 UI パターン

### ボトムタブナビゲーション
`MainScreen` はタブの永続性のために `IndexedStack` を使用:
- 🚚 配送マップ（メイン画面）
- 🏠 避難所情報
- 将来的には統計/設定タブを追加予定

### Material Design 3
- `ColorScheme.fromSeed(seedColor: Colors.blue)`
- 緊急サービスの外観に適した一貫した青色テーマ
- インターフェース全体で日本語テキストを使用

このコードベースで作業する際は、セキュリティ検証を優先し、シンプルなアーキテクチャパターンを維持し、すべての Firebase 操作が確立されたサービスレイヤーを通過することを確認してください。