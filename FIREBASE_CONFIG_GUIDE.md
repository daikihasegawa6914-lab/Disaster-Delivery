# 🔐 Firebase設定ガイド

## 📁 ファイル構成

### **開発環境用**
- `lib/firebase_options.dart` - 開発用Firebase設定
- `android/app/google-services.json` - Android開発用
- `ios/Runner/GoogleService-Info.plist` - iOS開発用

**注意**: 開発用Firebaseプロジェクトはテストデータのみを使用し、セキュリティルールで保護されています。

### **本番環境用**
- `lib/firebase_options_production.dart` - 本番用Firebase設定
- `android/app/google-services-production.json` - Android本番用
- `ios/Runner/GoogleService-Info-production.plist` - iOS本番用

**管理方法**: 本番用ファイルは`.gitignore`で除外されています。

---

## 🚀 デプロイ手順

### **本番デプロイ前の準備**
1. 本番用Firebaseプロジェクトを作成。
2. 本番用設定ファイルをダウンロード。
3. ファイル名を`_production`付きに変更。
4. アプリ設定を本番用に切り替え。

### **セキュリティ対策**
- 開発用プロジェクトは制限されたテストデータのみを使用。
- 本番用プロジェクトには厳格なセキュリティルールを適用。
- API使用量を監視し、アラートを設定。

---

## ✅ 現在の状態

- **開発環境**: テストデータのみを使用し、安全に運用中。
- **本番準備**: 発表前日に本番用設定へ切り替え予定。

このガイドは、Firebase設定の安全な管理と効率的なデプロイをサポートします。