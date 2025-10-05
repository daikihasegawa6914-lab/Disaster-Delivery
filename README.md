# 災害配達員支援デリバリー

このリポジトリは、災害時に配達員が避難所や被災者を支援するためのシンプルな配送アプリです。配達員がプロフィール登録を行い、マップ上で配送依頼を引き受け、完了報告を行うまでの基本機能を提供します。

## 提供する画面
1. **プロフィール登録** (`ProfileSetupScreen`)
2. **メインタブ** (`MainScreen`)
   - **配達マップ** (`DeliveryMapScreen`): リアルタイム依頼表示、引き受け、完了
   - **避難所一覧** (`ShelterScreen`): Firestoreの`shelters`コレクションを参照（読み取り専用）

## データコレクション
- `delivery_persons`: 配達員プロフィール（匿名認証UIDをドキュメントIDとして使用）
- `requests`: 配送依頼（ステータス: waiting / assigned / delivering / completed）
- `shelters`: 避難所情報（読み取り専用）

## Firebase 認証
- **匿名認証**: アプリ起動時に自動実行。
- **Firestore ルール**: `request.auth != null` を満たす必要あり。

## 主要ファイル
```
lib/
  main.dart                 // アプリのエントリーポイント
  main_screen.dart          // タブナビゲーション（マップ / 避難所）
  delivery_map_screen.dart  // 配送依頼の表示、引き受け、完了
  profile_setup_screen.dart // 初回プロフィール登録
  services.dart             // Firestore操作
  models.dart               // データモデル定義
  constants.dart            // ステータスや優先度の定数
  security/                 // セキュリティ関連モジュール
    secure_error_handler.dart
    optimized_firestore.dart
```

## セットアップ手順
1. Firebase プロジェクトを作成し、Android / iOS アプリを登録。
2. 設定ファイルを配置:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. `lib/firebase_options.dart.example` をコピーして編集:
   ```bash
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   ```
4. 依存関係を取得:
   ```bash
   flutter pub get
   ```
5. アプリを実行:
   ```bash
   flutter run
   ```

## 開発メモ
- 初期テストデータの投入コードは無効化済み（本番ルール準拠）。
- 配送依頼の作成は現在アプリ内UIに未実装（Firestoreで直接追加して動作確認）。
- 配達引き受けは `status == waiting` の条件でのみ可能。

## ライセンス
MIT
