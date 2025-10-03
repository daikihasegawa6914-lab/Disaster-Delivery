## 災害配達員ミニマルアプリ

本リポジトリは「配達員がプロフィール登録 → マップで配送依頼を引き受け → 完了報告」までの最短動線のみを残したシンプル版です。余剰ドキュメントと将来構想は削除し、現在必要な事実のみを記載します。

### 現在提供する画面
1. プロフィール登録 (`ProfileSetupScreen`)
2. メインタブ (`MainScreen`)
   - 配達マップ (`DeliveryMapScreen`) : リアルタイム依頼表示 / 引き受け / 完了
   - 避難所一覧 (`ShelterScreen`) : Firestoreの`shelters`参照（読み取りのみ）

### データコレクション
- `delivery_persons`: 配達員プロフィール (匿名認証UID = ドキュメントID)
- `requests`: 配送依頼（ステータス: waiting / assigned / delivering / completed）
- `shelters`: 避難所情報（読み取りのみ）

### 認証
- Firebase Anonymous Auth を起動時に強制実行（Firestore ルール `request.auth != null` 満たす）

### 主要ファイル
```
lib/
  main.dart                 // 起動 & 匿名認証 & フロー分岐
  main_screen.dart          // タブ (マップ / 避難所)
  delivery_map_screen.dart  // 依頼表示/引き受け/完了
  profile_setup_screen.dart // 初回プロフィール登録
  services.dart             // Firestore操作
  models.dart               // モデル定義
  constants.dart            // ステータス/優先度定数
  security/ (最小限稼働)
    secure_error_handler.dart
    optimized_firestore.dart
```

### セットアップ手順（最小）
1. Firebase プロジェクトを作成し Android / iOS アプリ登録
2. 設定ファイル配置:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. `cp lib/firebase_options.dart.example lib/firebase_options.dart` を編集
4. 依存取得: `flutter pub get`
5. 実行: `flutter run`

### 開発メモ
- 初期テストデータ投入コードは無効化（本番ルール準拠のため）
- 依頼作成は現在アプリ内UI無し（外部でFirestoreへ直接追加して動作確認）
- 競合防止のため配達引き受けは `status == waiting` を条件に `assignDelivery` で更新

### ライセンス
MIT
