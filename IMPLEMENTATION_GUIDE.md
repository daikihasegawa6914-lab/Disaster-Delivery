# 🔥 Firebase + API 統合実装ガイド

## 📋 フローチャート対応実装

フローチャートの画面遷移をFirebaseとGoogle Maps APIで実装する現実的なガイドです。

---

## 🛠️ **Firebase設定（Day 1前半）**

### 📱 **必要なFirebaseサービス**

| サービス | 用途 | 実装難易度 | 所要時間 |
|---------|------|-----------|----------|
| **Authentication** | ログイン/登録 | ⭐⭐ | 2時間 |
| **Firestore** | データ保存 | ⭐⭐ | 3時間 |
| **Cloud Messaging** | プッシュ通知 | ⭐ | 1時間 |
| **Storage** | 画像保存（オプション） | ⭐ | 1時間 |

### 🔧 **pubspec.yaml 設定**

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_messaging: ^14.7.10
  
  # Google Maps
  google_maps_flutter: ^2.5.0
  geolocator: ^10.1.0
  geocoding: ^2.1.1
  
  # UI & State Management
  provider: ^6.1.1
  fluttertoast: ^8.2.4
  
  # Utilities
  intl: ^0.18.1
  shared_preferences: ^2.2.2
```

---

## 🏗️ **データ構造設計**

### 📊 **Firestore コレクション構成**

```typescript
// users コレクション
{
  "userId": {
    "name": "田中太郎",
    "email": "tanaka@example.com",
    "phone": "090-1234-5678",
    "address": "東京都渋谷区...",
    "userType": "victim", // "victim" | "delivery_person"
    "createdAt": timestamp,
    "isActive": true
  }
}

// delivery_persons コレクション
{
  "deliveryPersonId": {
    "name": "配送太郎",
    "rating": 4.8,
    "available": true,
    "currentLocation": {
      "latitude": 35.6762,
      "longitude": 139.6503
    },
    "vehicle": "bicycle", // "bicycle" | "motorcycle" | "car"
    "capacity": 10 // kg
  }
}

// orders コレクション
{
  "orderId": {
    "victimId": "user123",
    "deliveryPersonId": "delivery456",
    "items": ["水", "食料", "毛布"],
    "deliveryAddress": "東京都渋谷区...",
    "status": "ordered", // "ordered" | "assigned" | "in_progress" | "completed"
    "createdAt": timestamp,
    "completedAt": timestamp,
    "priority": "high" // "low" | "medium" | "high"
  }
}
```

---

## 📱 **画面別実装詳細**

### 🔐 **1. ログイン実装（Firebase Auth）**

```dart
// lib/services/auth_service.dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // ログイン
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print('ログインエラー: $e');
      return null;
    }
  }
  
  // 新規登録
  Future<User?> registerWithEmail(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Firestoreにユーザー情報保存
      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'name': name,
        'email': email,
        'userType': 'victim',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      
      return result.user;
    } catch (e) {
      print('登録エラー: $e');
      return null;
    }
  }
  
  // ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
```

### 🏠 **2. ホーム画面実装（Firestore連携）**

```dart
// lib/screens/home_screen.dart
class HomeScreen extends StatelessWidget {
  final AuthService _authService = AuthService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('災害配送'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 現在の注文状況確認
          _buildOrderStatusCard(),
          
          // 新規配送依頼
          _buildNewRequestCard(context),
          
          // 緊急要請
          _buildEmergencyRequestCard(context),
        ],
      ),
    );
  }
  
  Widget _buildOrderStatusCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('victimId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('status', whereIn: ['ordered', 'assigned', 'in_progress'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        var activeOrders = snapshot.data!.docs;
        
        return Card(
          child: ListTile(
            leading: Icon(Icons.local_shipping),
            title: Text('進行中の配送'),
            subtitle: Text('${activeOrders.length}件'),
            onTap: () => Navigator.pushNamed(context, '/order-status'),
          ),
        );
      },
    );
  }
  
  Widget _buildNewRequestCard(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.add_shopping_cart),
        title: Text('配送依頼'),
        subtitle: Text('物資の配送を依頼'),
        onTap: () => Navigator.pushNamed(context, '/request-form'),
      ),
    );
  }
}
```

### 📍 **3. 配送者選択（Google Maps + Firestore）**

```dart
// lib/screens/delivery_selection_screen.dart
class DeliverySelectionScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  
  @override
  _DeliverySelectionScreenState createState() => _DeliverySelectionScreenState();
}

class _DeliverySelectionScreenState extends State<DeliverySelectionScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<DeliveryPerson> _deliveryPersons = [];
  
  @override
  void initState() {
    super.initState();
    _loadDeliveryPersons();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('配送者選択')),
      body: Column(
        children: [
          // Google Maps表示
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(35.6762, 139.6503),
                zoom: 13,
              ),
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
          ),
          
          // 配送者リスト
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: _deliveryPersons.length,
              itemBuilder: (context, index) {
                var person = _deliveryPersons[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(person.name[0]),
                  ),
                  title: Text(person.name),
                  subtitle: Text('評価: ${person.rating} ⭐ • ${person.vehicle}'),
                  trailing: ElevatedButton(
                    onPressed: () => _selectDeliveryPerson(person),
                    child: Text('選択'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Firestoreから利用可能な配送者を取得
  void _loadDeliveryPersons() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('delivery_persons')
        .where('available', isEqualTo: true)
        .get();
    
    List<DeliveryPerson> persons = [];
    Set<Marker> markers = {};
    
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      var person = DeliveryPerson.fromMap(doc.id, data);
      persons.add(person);
      
      // マーカー追加
      markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(
            person.currentLocation.latitude,
            person.currentLocation.longitude,
          ),
          infoWindow: InfoWindow(
            title: person.name,
            snippet: '評価: ${person.rating} ⭐',
          ),
        ),
      );
    }
    
    setState(() {
      _deliveryPersons = persons;
      _markers = markers;
    });
  }
  
  // 配送者選択処理
  void _selectDeliveryPerson(DeliveryPerson person) async {
    // Firestoreに注文作成
    DocumentReference orderRef = await FirebaseFirestore.instance
        .collection('orders')
        .add({
      'victimId': FirebaseAuth.instance.currentUser?.uid,
      'deliveryPersonId': person.id,
      'items': widget.requestData['items'],
      'deliveryAddress': widget.requestData['address'],
      'status': 'assigned',
      'createdAt': FieldValue.serverTimestamp(),
      'priority': widget.requestData['priority'] ?? 'medium',
    });
    
    // 配送者の状態更新
    await FirebaseFirestore.instance
        .collection('delivery_persons')
        .doc(person.id)
        .update({'available': false});
    
    // プッシュ通知送信（配送者へ）
    await _sendNotificationToDeliveryPerson(person.id, orderRef.id);
    
    // ステータス画面へ遷移
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderStatusScreen(orderId: orderRef.id),
      ),
    );
  }
  
  // プッシュ通知送信
  Future<void> _sendNotificationToDeliveryPerson(String deliveryPersonId, String orderId) async {
    // Firebase Cloud Messaging実装
    // 実際の実装では Cloud Functions を使用
  }
}
```

### 📦 **4. 注文ステータス（リアルタイム更新）**

```dart
// lib/screens/order_status_screen.dart
class OrderStatusScreen extends StatelessWidget {
  final String orderId;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('配送状況')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          var order = snapshot.data!.data() as Map<String, dynamic>;
          
          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ステータス進捗表示
                _buildStatusProgress(order['status']),
                
                SizedBox(height: 20),
                
                // 注文詳細
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('注文ID: ${orderId.substring(0, 8)}...'),
                        Text('配送先: ${order['deliveryAddress']}'),
                        Text('物資: ${(order['items'] as List).join(", ")}'),
                        if (order['deliveryPersonId'] != null)
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('delivery_persons')
                                .doc(order['deliveryPersonId'])
                                .get(),
                            builder: (context, personSnapshot) {
                              if (personSnapshot.hasData) {
                                var person = personSnapshot.data!.data() as Map<String, dynamic>;
                                return Text('配送者: ${person['name']}');
                              }
                              return Text('配送者: 読み込み中...');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // アクションボタン
                if (order['status'] == 'in_progress')
                  ElevatedButton(
                    onPressed: () => _contactDeliveryPerson(order['deliveryPersonId']),
                    child: Text('配送者に連絡'),
                  ),
                
                if (order['status'] == 'completed')
                  ElevatedButton(
                    onPressed: () => _rateDelivery(order),
                    child: Text('評価する'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildStatusProgress(String status) {
    List<String> statuses = ['ordered', 'assigned', 'in_progress', 'completed'];
    int currentIndex = statuses.indexOf(status);
    
    return Column(
      children: [
        for (int i = 0; i < statuses.length; i++)
          _buildStatusStep(
            _getStatusLabel(statuses[i]),
            i <= currentIndex,
            i == currentIndex,
          ),
      ],
    );
  }
  
  Widget _buildStatusStep(String label, bool completed, bool current) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? Colors.green : Colors.grey,
            border: current ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: completed
              ? Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: current ? FontWeight.bold : FontWeight.normal,
            color: completed ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }
  
  String _getStatusLabel(String status) {
    switch (status) {
      case 'ordered': return '注文受付';
      case 'assigned': return '配送者決定';
      case 'in_progress': return '配送中';
      case 'completed': return '配送完了';
      default: return status;
    }
  }
}
```

---

## 📊 **データモデル定義**

```dart
// lib/models/delivery_person.dart
class DeliveryPerson {
  final String id;
  final String name;
  final double rating;
  final bool available;
  final LatLng currentLocation;
  final String vehicle;
  final int capacity;
  
  DeliveryPerson({
    required this.id,
    required this.name,
    required this.rating,
    required this.available,
    required this.currentLocation,
    required this.vehicle,
    required this.capacity,
  });
  
  factory DeliveryPerson.fromMap(String id, Map<String, dynamic> map) {
    return DeliveryPerson(
      id: id,
      name: map['name'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      available: map['available'] ?? false,
      currentLocation: LatLng(
        map['currentLocation']['latitude'] ?? 0.0,
        map['currentLocation']['longitude'] ?? 0.0,
      ),
      vehicle: map['vehicle'] ?? 'bicycle',
      capacity: map['capacity'] ?? 10,
    );
  }
}
```

---

## 🔔 **プッシュ通知実装**

```dart
// lib/services/notification_service.dart
class NotificationService {
  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // 権限要求
    NotificationSettings settings = await messaging.requestPermission();
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('プッシュ通知許可済み');
      
      // フォアグラウンド通知の処理
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });
      
      // バックグラウンド通知の処理
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message);
      });
    }
  }
  
  static void _showLocalNotification(RemoteMessage message) {
    // ローカル通知表示
    Fluttertoast.showToast(
      msg: message.notification?.body ?? '',
      toastLength: Toast.LENGTH_LONG,
    );
  }
  
  static void _handleNotificationTap(RemoteMessage message) {
    // 通知タップ時の処理
    if (message.data['orderId'] != null) {
      // 注文詳細画面に遷移
    }
  }
}
```

---

## 🎯 **実装優先順位**

### **Day 1**: Firebase基盤
1. Firebase設定・認証実装
2. Firestore基本構造作成
3. ログイン/登録画面

### **Day 2-3**: 基本画面
1. ホーム画面実装
2. 要請フォーム作成
3. Firestore CRUD操作

### **Day 4-5**: 地図・選択機能
1. Google Maps統合
2. 配送者選択機能
3. リアルタイムデータ更新

### **Day 6-7**: 高度機能
1. プッシュ通知実装
2. ステータス追跡
3. UI/UX調整

### **Day 8**: テスト・調整
1. 全体テスト
2. エラーハンドリング
3. プレゼン準備

この構成で、フローチャートに基づいた**現実的で理解しやすい災害配送アプリ**が8日間で完成します。