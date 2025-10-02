# 📱 実際の電話番号認証設定ガイド

## 🎯 現在の問題

- **開発用固定番号**: `090-1234-5678` のみで動作
- **本格運用**: 実際のユーザー電話番号に対応が必要

## 🔧 Firebase Console 設定手順

### 1. Firebase Console にアクセス
```
https://console.firebase.google.com/
→ プロジェクト選択: disaster-delivery-app
→ Authentication → Sign-in method
```

### 2. 電話番号認証の有効化
```
Sign-in providers:
✅ Phone ← これを有効にする

設定項目:
• reCAPTCHA verification for web (推奨: 有効)
• App Verification (iOS): 自動設定
• SHA証明書 (Android): 必要に応じて追加
```

### 3. テスト用電話番号の設定
```
Authentication → Settings → Phone numbers for testing

追加例:
📱 電話番号: +819012345678
🔐 認証コード: 123456

注意: テスト番号は10個まで登録可能
```

### 4. 本番用の設定

#### 4.1 reCAPTCHA 設定 (Web用)
```
Google Cloud Console:
→ APIs & Services
→ reCAPTCHA Enterprise API (有効化)
```

#### 4.2 Android SHA-1 証明書
```bash
# デバッグ用証明書の取得
cd android
./gradlew signingReport

# 本番用証明書 (Google Play Console から取得)
```

#### 4.3 iOS APN 設定
```
Apple Developer Console:
→ Certificates, Identifiers & Profiles
→ Keys → APNs Auth Key 作成
→ Firebase Console にアップロード
```

## 🚀 本番運用への移行

### 開発モードの無効化
```dart
// login_screen.dart で開発用ボタンを本番では非表示
if (const bool.fromEnvironment('dart.vm.product') == false) {
  // 開発用テストモードボタン
}
```

### 本番ビルド
```bash
# Android 本番ビルド
flutter build apk --release

# iOS 本番ビルド  
flutter build ios --release
```

## 📊 SMS送信料金について

Firebase Authentication SMS:
- **無料枠**: 月10,000回まで
- **超過料金**: 地域により異なる
- **日本**: 約 ¥10-15 / SMS

## 🛡️ セキュリティ考慮点

1. **reCAPTCHA**: スパム防止のため必須
2. **レート制限**: 同一番号からの過度なリクエスト制限
3. **認証コード**: 6桁、有効期限付き
4. **国際番号**: +81 形式での統一管理

## 🧪 テスト手順

### 開発環境
```
1. アプリ起動
2. "🛠️ 開発用テストモード" タップ
3. 認証コード: 123456 入力
```

### 本番テスト
```
1. Firebase Console でテスト番号追加
2. アプリで該当番号入力
3. 設定した認証コード入力
```

### 実機テスト
```
1. 実際の携帯番号入力
2. SMS受信確認
3. 6桁コード入力
```

## 🚨 トラブルシューティング

### SMS が届かない場合
1. 電話番号形式確認 (+81 から始まる)
2. 通信環境確認
3. 迷惑メール設定確認
4. Firebase quota 確認

### 認証エラーの場合
1. SHA証明書の設定確認
2. Bundle ID / Package Name 確認
3. reCAPTCHA設定確認
4. Firestore Rules 確認

## 📋 チェックリスト

本番リリース前:
- [ ] Firebase Console でSMS認証有効化
- [ ] reCAPTCHA設定完了
- [ ] Android SHA証明書追加
- [ ] iOS APNs設定完了
- [ ] テスト用電話番号で動作確認
- [ ] 実機での SMS 受信テスト
- [ ] 開発用テストモード無効化確認
- [ ] SMS送信料金の予算設定

## 🎯 今後の改善点

1. **多国籍対応**: 日本以外の電話番号形式
2. **SNS認証**: Google, Apple Sign-in の追加
3. **生体認証**: Face ID, Touch ID 対応
4. **2段階認証**: SMS + アプリ内認証