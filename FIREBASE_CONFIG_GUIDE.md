# 🔐 Firebase設定ファイル管理ガイド

## 📁 ファイル構成

### **開発環境用（GitHubに含む）**
- `lib/firebase_options.dart` - 開発用Firebase設定
- `android/app/google-services.json` - Android開発用
- `ios/Runner/GoogleService-Info.plist` - iOS開発用

**注意**: これらのファイルは開発に必要なため、GitHubに含まれています。
開発用のFirebaseプロジェクトを使用しており、本番データは含まれていません。

### **本番環境用（GitHubに含まない）**
- `lib/firebase_options_production.dart` - 本番用Firebase設定
- `android/app/google-services-production.json` - Android本番用  
- `ios/Runner/GoogleService-Info-production.plist` - iOS本番用

これらのファイルは`.gitignore`で除外済みです。

## 🚀 デプロイ時の手順

### **本番デプロイ前**
1. 本番用Firebaseプロジェクトを作成
2. 本番用設定ファイルをダウンロード
3. ファイル名を`_production`付きに変更
4. アプリの設定を本番用に切り替え

### **セキュリティ確保**
- 開発用プロジェクトは制限されたテストデータのみ
- 本番用プロジェクトは厳格なセキュリティルール
- API使用量の監視とアラート設定

## ✅ 現在の状態

**安全性**: 開発用のFirebase設定は公開されていますが、
- テストデータのみ含有
- 本番データへのアクセス権限なし
- セキュリティルールで保護済み

**本番準備**: 発表前日に本番用設定へ切り替え予定