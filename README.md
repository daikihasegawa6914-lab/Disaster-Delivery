# 🚚 災害配送システム（配達員アプリ）

短期ハッカソン向けに開発された災害時配送最適化アプリです。

## 📱 機能

- **配達マップ画面**: Google Maps統合、配送依頼の地図表示
- **避難所情報画面**: 避難所一覧と詳細情報
- **Firebase連携**: リアルタイムデータ同期
- **位置情報サービス**: GPS機能、現在地取得

## 🛠️ セットアップ

### 1. 前提条件
- Flutter SDK (3.0以上)
- Android Studio / Xcode
- Firebase プロジェクト

### 2. Firebase設定

1. Firebase Console でプロジェクトを作成
2. Android/iOS アプリを追加
3. 設定ファイルをダウンロード:
   ```
   android/app/google-services.json (Android用)
   ios/Runner/GoogleService-Info.plist (iOS用)
   ```
4. firebase_options.dart を作成:
   ```bash
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   # 実際のFirebase設定値を記入
   ```

### 3. 環境変数設定
```bash
cp .env.example .env
# .envファイルに実際のAPIキーを記入
```

### 4. 依存関係インストール
```bash
flutter pub get
```

### 5. 実行
```bash
flutter run
```

## 🏗️ 技術スタック

- **Framework**: Flutter/Dart
- **Map**: Google Maps API
- **Backend**: Firebase Firestore
- **Auth**: Firebase Authentication
- **Location**: Geolocator

## 📁 プロジェクト構造

```
lib/
├── main.dart                 # エントリーポイント
├── main_screen.dart          # メイン画面（タブナビゲーション）
├── delivery_map_screen.dart  # 配達マップ画面
├── shelter_screen.dart       # 避難所情報画面
├── models.dart              # データモデル
├── services.dart            # サービス層
└── security/                # セキュリティ機能
    ├── input_validator.dart
    ├── secure_error_handler.dart
    └── optimized_firestore.dart
```

## 🔒 セキュリティ

- 入力値検証
- APIキー保護
- Firestoreセキュリティルール
- エラーハンドリング

## 🚀 将来的な拡張

- 被災者側アプリとの統合
- プッシュ通知
- AI配送最適化
- リアルタイム災害情報

## 📄 ライセンス

MIT License

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
