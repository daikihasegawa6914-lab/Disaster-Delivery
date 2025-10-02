# 📅 8日間開発スケジュール詳細版

## 🎯 フローチャートベース実装計画

フローチャートの各画面をFirebase + APIで効率的に実装する詳細スケジュールです。

---

## 📊 **全体スケジュール概要**

| 日 | 主要タスク | 完成画面 | 所要時間 | 累積進捗 |
|----|-----------|----------|----------|----------|
| **Day 1** | Firebase設定 + ログイン | ログイン/登録 | 8h | 12% |
| **Day 2** | ホーム画面 + データ構造 | ホーム画面 | 8h | 25% |
| **Day 3** | 要請フォーム + Firestore | 要請作成 | 8h | 40% |
| **Day 4** | 地図表示 + 配送者選択 | 配送者選択 | 8h | 60% |
| **Day 5** | ステータス管理 + 通知 | 注文ステータス | 8h | 75% |
| **Day 6** | 配送完了 + エラー対応 | 全機能統合 | 8h | 90% |
| **Day 7** | UI調整 + テスト | 完成版 | 8h | 98% |
| **Day 8** | プレゼン準備 + 最終調整 | 発表準備 | 8h | 100% |

---

## 📅 **日別詳細スケジュール**

### 🚀 **Day 1: Firebase基盤構築**

#### ⏰ **時間配分**
- **09:00-11:00 (2h)**: Firebase プロジェクト設定
- **11:00-13:00 (2h)**: Flutter Firebase 統合
- **14:00-16:00 (2h)**: 認証機能実装
- **16:00-18:00 (2h)**: ログイン/登録画面 UI

#### ✅ **具体的タスク**

**09:00-11:00: Firebase セットアップ**
```bash
# Firebase プロジェクト作成
1. Firebase Console でプロジェクト作成
2. Android/iOS アプリ追加
3. google-services.json/GoogleService-Info.plist ダウンロード
4. pubspec.yaml に依存関係追加

# 必要パッケージ
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  google_maps_flutter: ^2.5.0
```

**11:00-13:00: Firebase 初期化**
```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

// lib/services/firebase_service.dart 作成
class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }
}
```

**14:00-16:00: 認証サービス実装**
```dart
// lib/services/auth_service.dart 作成
// - signInWithEmail()
// - registerWithEmail()
// - signOut()
// - getCurrentUser()
```

**16:00-18:00: ログイン画面 UI**
```dart
// lib/screens/login_screen.dart 作成
// - メールアドレス入力フィールド
// - パスワード入力フィールド
// - ログインボタン
// - 新規登録ボタン
// - エラーメッセージ表示
```

#### 🎯 **Day 1 完了基準**
- [ ] Firebase プロジェクトが正常に接続
- [ ] メール/パスワードでログイン可能
- [ ] 新規ユーザー登録が機能
- [ ] エラーハンドリングが実装済み

---

### 🏠 **Day 2: ホーム画面 + データ構造**

#### ⏰ **時間配分**
- **09:00-11:00 (2h)**: Firestore データ構造設計
- **11:00-13:00 (2h)**: ホーム画面 UI 実装
- **14:00-16:00 (2h)**: Firestore CRUD 基本操作
- **16:00-18:00 (2h)**: 画面遷移ロジック

#### ✅ **具体的タスク**

**09:00-11:00: Firestore 設計**
```typescript
// users コレクション
{
  "userId": {
    "name": string,
    "email": string,
    "userType": "victim" | "delivery_person",
    "createdAt": timestamp
  }
}

// orders コレクション
{
  "orderId": {
    "victimId": string,
    "items": string[],
    "status": "ordered" | "assigned" | "in_progress" | "completed",
    "createdAt": timestamp
  }
}
```

**11:00-13:00: ホーム画面 UI**
```dart
// lib/screens/home_screen.dart
// - AppBar (タイトル + ログアウト)
// - 配送情報確認カード
// - 要請・物資依頼カード
// - 緊急要請ボタン
```

**14:00-16:00: Firestore 操作**
```dart
// lib/services/firestore_service.dart
class FirestoreService {
  // ユーザーデータ保存
  Future<void> saveUserData(User user, Map<String, dynamic> data);
  
  // 注文作成
  Future<String> createOrder(Map<String, dynamic> orderData);
  
  // 注文一覧取得
  Stream<QuerySnapshot> getUserOrders(String userId);
}
```

**16:00-18:00: 画面遷移**
```dart
// lib/routes/app_routes.dart
// - ログイン → ホーム
// - ホーム → 要請フォーム
// - ホーム → ステータス確認
```

#### 🎯 **Day 2 完了基準**
- [ ] ホーム画面が正常表示
- [ ] Firestore への読み書きが機能
- [ ] 画面間の遷移が動作
- [ ] ユーザーデータが正しく保存

---

### 📝 **Day 3: 要請フォーム + データ保存**

#### ⏰ **時間配分**
- **09:00-11:00 (2h)**: 要請フォーム UI 作成
- **11:00-13:00 (2h)**: フォームバリデーション
- **14:00-16:00 (2h)**: Firestore データ保存
- **16:00-18:00 (2h)**: 住所 → 座標変換 (Geocoding)

#### ✅ **具体的タスク**

**09:00-11:00: 要請フォーム UI**
```dart
// lib/screens/request_form_screen.dart
// - 物資選択 (チェックボックス)
// - 住所入力
// - 緊急度選択 (ラジオボタン)
// - 備考欄
// - 送信ボタン
```

**11:00-13:00: バリデーション**
```dart
// lib/utils/form_validator.dart
class FormValidator {
  static String? validateAddress(String? value);
  static String? validateItems(List<String> items);
  static bool isFormValid(Map<String, dynamic> formData);
}
```

**14:00-16:00: データ保存**
```dart
// orders コレクションに保存
{
  "victimId": currentUser.uid,
  "items": ["水", "食料"],
  "deliveryAddress": "東京都渋谷区...",
  "priority": "high",
  "status": "ordered",
  "createdAt": FieldValue.serverTimestamp()
}
```

**16:00-18:00: Geocoding API**
```dart
// lib/services/location_service.dart
class LocationService {
  static Future<LatLng> getCoordinatesFromAddress(String address) async {
    List<Location> locations = await locationFromAddress(address);
    return LatLng(locations.first.latitude, locations.first.longitude);
  }
}
```

#### 🎯 **Day 3 完了基準**
- [ ] 要請フォームが動作
- [ ] 入力バリデーションが機能
- [ ] Firestore に正しくデータ保存
- [ ] 住所から座標変換が成功

---

### 🗺️ **Day 4: 地図表示 + 配送者選択**

#### ⏰ **時間配分**
- **09:00-11:00 (2h)**: Google Maps 統合
- **11:00-13:00 (2h)**: 配送者データ準備
- **14:00-16:00 (2h)**: マーカー表示機能
- **16:00-18:00 (2h)**: 配送者選択ロジック

#### ✅ **具体的タスク**

**09:00-11:00: Google Maps 設定**
```dart
// android/app/src/main/AndroidManifest.xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>

// lib/screens/delivery_selection_screen.dart
GoogleMap(
  initialCameraPosition: CameraPosition(
    target: LatLng(35.6762, 139.6503),
    zoom: 13,
  ),
  onMapCreated: (GoogleMapController controller) {
    _mapController = controller;
  },
)
```

**11:00-13:00: 配送者データ**
```dart
// delivery_persons コレクション作成
{
  "name": "配送太郎",
  "rating": 4.8,
  "available": true,
  "currentLocation": {
    "latitude": 35.6762,
    "longitude": 139.6503
  },
  "vehicle": "bicycle"
}
```

**14:00-16:00: マーカー表示**
```dart
// 配送者位置をマーカーで表示
Set<Marker> _buildDeliveryPersonMarkers() {
  return _deliveryPersons.map((person) {
    return Marker(
      markerId: MarkerId(person.id),
      position: person.currentLocation,
      infoWindow: InfoWindow(
        title: person.name,
        snippet: '評価: ${person.rating} ⭐',
      ),
    );
  }).toSet();
}
```

**16:00-18:00: 選択機能**
```dart
// 配送者選択処理
void _selectDeliveryPerson(DeliveryPerson person) async {
  await FirebaseFirestore.instance
      .collection('orders')
      .doc(currentOrderId)
      .update({
    'deliveryPersonId': person.id,
    'status': 'assigned',
    'assignedAt': FieldValue.serverTimestamp(),
  });
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => OrderStatusScreen(orderId: currentOrderId),
    ),
  );
}
```

#### 🎯 **Day 4 完了基準**
- [ ] Google Maps が正常表示
- [ ] 配送者マーカーが地図上に表示
- [ ] 配送者選択機能が動作
- [ ] 選択後のデータ更新が成功

---

### 📊 **Day 5: ステータス管理 + 通知**

#### ⏰ **時間配分**
- **09:00-11:00 (2h)**: ステータス画面 UI
- **11:00-13:00 (2h)**: リアルタイム更新
- **14:00-16:00 (2h)**: プッシュ通知基盤
- **16:00-18:00 (2h)**: 通知送信ロジック

#### ✅ **具体的タスク**

**09:00-11:00: ステータス画面**
```dart
// lib/screens/order_status_screen.dart
// - 進捗インジケーター
// - 注文詳細表示
// - 配送者情報
// - 連絡ボタン
```

**11:00-13:00: リアルタイム更新**
```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots(),
  builder: (context, snapshot) {
    // ステータス変更を自動反映
  },
)
```

**14:00-16:00: FCM 設定**
```dart
// lib/services/notification_service.dart
class NotificationService {
  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // 権限要求
    await messaging.requestPermission();
    
    // フォアグラウンド通知処理
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }
}
```

**16:00-18:00: 通知送信**
```dart
// ステータス変更時の通知
Future<void> _updateOrderStatus(String orderId, String newStatus) async {
  await FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .update({'status': newStatus});
  
  // 通知送信
  await _sendNotification(orderId, newStatus);
}
```

#### 🎯 **Day 5 完了基準**
- [ ] ステータス画面が動作
- [ ] リアルタイム更新が機能
- [ ] プッシュ通知が受信可能
- [ ] 状態変更通知が送信される

---

### 🔧 **Day 6: 機能統合 + エラー対応**

#### ⏰ **時間配分**
- **09:00-11:00 (2h)**: 全画面遷移テスト
- **11:00-13:00 (2h)**: エラーハンドリング強化
- **14:00-16:00 (2h)**: データ整合性チェック
- **16:00-18:00 (2h)**: パフォーマンス最適化

#### ✅ **具体的タスク**

**09:00-11:00: 統合テスト**
```dart
// フローテスト手順
1. ユーザー登録
2. ログイン
3. 配送要請作成
4. 配送者選択
5. ステータス確認
6. 完了処理
```

**11:00-13:00: エラー処理**
```dart
// lib/utils/error_handler.dart
class ErrorHandler {
  static void handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'network-request-failed':
        _showError('ネットワークエラー');
        break;
      case 'permission-denied':
        _showError('権限が不足しています');
        break;
      default:
        _showError('エラーが発生しました: ${e.message}');
    }
  }
}
```

**14:00-16:00: データ検証**
```dart
// データ整合性チェック
Future<bool> _validateOrderData(Map<String, dynamic> order) async {
  // 必須フィールドチェック
  if (order['victimId'] == null) return false;
  if (order['items'] == null || order['items'].isEmpty) return false;
  
  // ユーザー存在確認
  DocumentSnapshot user = await FirebaseFirestore.instance
      .collection('users')
      .doc(order['victimId'])
      .get();
  
  return user.exists;
}
```

**16:00-18:00: 最適化**
```dart
// キャッシュ設定
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);

// 画像最適化
// 不要なウィジェット削除
// メモリリーク対策
```

#### 🎯 **Day 6 完了基準**
- [ ] 全機能が連携して動作
- [ ] エラーが適切に処理される
- [ ] データ不整合が発生しない
- [ ] アプリが安定動作

---

### 🎨 **Day 7: UI調整 + 最終テスト**

#### ⏰ **時間配分**
- **09:00-11:00 (2h)**: UI/UX 改善
- **11:00-13:00 (2h)**: レスポンシブ対応
- **14:00-16:00 (2h)**: 実機テスト
- **16:00-18:00 (2h)**: デモデータ準備

#### ✅ **具体的タスク**

**09:00-11:00: UI 改善**
```dart
// マテリアルデザイン適用
// 色彩統一
// アイコン統一
// フォント調整
// 余白調整
```

**11:00-13:00: レスポンシブ**
```dart
// 画面サイズ対応
// タブレット対応
// 横画面対応
// キーボード表示対応
```

**14:00-16:00: 実機テスト**
```dart
// Android デバイステスト
// iOS デバイステスト
// 各機能動作確認
// パフォーマンステスト
```

**16:00-18:00: デモ準備**
```dart
// サンプルユーザー作成
// サンプル配送者作成
// デモシナリオ作成
// スクリーンショット撮影
```

#### 🎯 **Day 7 完了基準**
- [ ] UI が統一され美しい
- [ ] 全デバイスで正常動作
- [ ] デモ用データが準備完了
- [ ] プレゼン用素材が揃っている

---

### 🎤 **Day 8: プレゼン準備 + 最終調整**

#### ⏰ **時間配分**
- **09:00-11:00 (2h)**: プレゼン資料作成
- **11:00-13:00 (2h)**: デモシナリオ練習
- **14:00-16:00 (2h)**: 最終バグ修正
- **16:00-18:00 (2h)**: 発表練習

#### ✅ **具体的タスク**

**09:00-11:00: 資料作成**
```markdown
# プレゼン構成
1. 問題提起 (30秒)
2. アプリデモ (90秒)
3. 技術説明 (45秒)
4. まとめ (15秒)
```

**11:00-13:00: デモ練習**
```dart
// デモシナリオ
1. ログイン → ホーム画面
2. 配送要請作成
3. 配送者選択
4. ステータス確認
5. 完了確認
```

**14:00-16:00: 最終調整**
```dart
// バグ修正
// 表示調整
// 動作確認
// バックアップ準備
```

**16:00-18:00: 発表練習**
```markdown
# 練習ポイント
- 時間内での説明
- デモの安定動作
- 質問への回答準備
- 緊張対策
```

#### 🎯 **Day 8 完了基準**
- [ ] 3分間で完璧にデモ可能
- [ ] 技術説明が簡潔で分かりやすい
- [ ] 想定質問に回答準備完了
- [ ] 自信を持って発表可能

---

## 🛡️ **リスク対策**

### ⚠️ **想定リスク & 対策**

| リスク | 発生確率 | 対策 |
|-------|----------|------|
| **Firebase接続エラー** | 中 | エラーハンドリング強化 |
| **Google Maps API制限** | 低 | 無料枠内で使用 |
| **実機動作不具合** | 中 | 早期実機テスト |
| **時間不足** | 高 | 機能優先順位明確化 |

### 🚨 **緊急時プラン**

**時間不足の場合**:
1. プッシュ通知機能削除
2. UI を基本デザインに簡素化
3. エラーハンドリング最小化

**技術的問題の場合**:
1. Firebase → ローカルストレージに変更
2. Google Maps → 静的地図に変更
3. リアルタイム更新 → 手動更新に変更

この詳細スケジュールにより、**フローチャートに基づいた現実的な災害配送アプリ**を確実に8日間で完成させることができます。