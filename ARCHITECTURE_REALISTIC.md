# 🏗️ 災害配送システム アーキテクチャ設計（フローベース実装）

## 📋 プロジェクト制約

**⏰ 開発期間**: 8日間  
**🎤 プレゼン時間**: 3分間  
**👨‍💻 開発規模**: 1人開発（学習プロジェクト）  
**🎯 技術レベル**: Firebase基本 + Flutter + 理解しやすいロジック

---

## 🏗️ **フローチャートベースのシステム設計**

### 📱 **画面フロー（フローチャート対応）**

```
┌─────────────────────────────────────────────────────────────┐
│                   🚚 災害配送アプリ                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  � ログイン/登録 → 🏠 ホーム → 📍 配送者選択 → 📦 注文ステータス │
│                    (被災者)   (マップ表示)    (進捗管理)      │
│                       ↓           ↓            ↓           │
│                  🚀 要請作成   ✅ 依頼作成   ⏱️ 通知         │
│                       ↓           ↓            ↓           │
│                  📊 情報確認   📋 配送選択   ✅ 配送完了     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 🛠️ **技術スタック（実用的構成）**

| 技術要素 | 採用技術 | 学習期間 | 実装期間 | 理解度 |
|---------|----------|----------|----------|--------|
| **認証** | Firebase Authentication | 1日 | 1日 | ⭐⭐ |
| **DB** | Firestore | 1日 | 2日 | ⭐⭐ |
| **UI** | Flutter基本Widget | 1日 | 2日 | ⭐⭐ |
| **地図** | Google Maps API | 0.5日 | 1日 | ⭐⭐ |
| **通知** | Firebase Cloud Messaging | 0.5日 | 0.5日 | ⭐ |
| **状態管理** | Provider/setState | 0.5日 | 0.5日 | ⭐ |

**✅ 採用技術（理解しやすく実用的）:**
- ✅ Firebase（認証・DB・通知）- 基本機能のみ
- ✅ Google Maps API - 地図表示・マーカー配置
- ✅ 基本的なCRUD操作
- ✅ シンプルな状態管理

**❌ 不採用技術（複雑すぎる）:**
- ❌ 高度なAI/ML アルゴリズム
- ❌ 複雑な最適化計算
- ❌ リアルタイム位置追跡
- ❌ 高度な分析・予測

---

## 📱 **画面別実装詳細（フローチャート対応）**

### 🔐 **1. ログイン/登録画面（Day 1）**

#### ✅ **実装内容**
```dart
class LoginScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('災害配送ログイン')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // メール・パスワード入力
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'メールアドレス'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'パスワード'),
              obscureText: true,
            ),
            
            // ログインボタン
            ElevatedButton(
              onPressed: () => _loginWithFirebase(),
              child: Text('ログイン'),
            ),
            
            // 新規登録ボタン
            TextButton(
              onPressed: () => _registerWithFirebase(),
              child: Text('新規登録'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Firebase認証
  Future<void> _loginWithFirebase() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログインエラー: $e')),
      );
    }
  }
}
```

### 🏠 **2. ホーム画面（被災者用）（Day 2）**

#### ✅ **実装内容**
```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('災害配送'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 配送情報確認機能
          Card(
            child: ListTile(
              leading: Icon(Icons.info),
              title: Text('配送情報確認'),
              subtitle: Text('現在の配送状況を確認'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InfoScreen()),
              ),
            ),
          ),
          
          // 要請・物資依頼フォーム
          Card(
            child: ListTile(
              leading: Icon(Icons.add_shopping_cart),
              title: Text('要請・物資依頼'),
              subtitle: Text('新しい配送を要請'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RequestFormScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 📍 **3. 配送者選択画面（マップ表示）（Day 3-4）**

#### ✅ **実装内容**
```dart
class DeliverySelectionScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('配送者選択')),
      body: Column(
        children: [
          // Google Map表示
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(35.6762, 139.6503), // 東京
                zoom: 12,
              ),
              markers: _buildDeliveryPersonMarkers(),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
          ),
          
          // 配送者リスト
          Expanded(
            flex: 1,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('delivery_persons')
                  .where('available', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var person = snapshot.data!.docs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(person['name'][0]),
                      ),
                      title: Text(person['name']),
                      subtitle: Text('評価: ${person['rating']} ⭐'),
                      trailing: ElevatedButton(
                        onPressed: () => _selectDeliveryPerson(person.id),
                        child: Text('選択'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### 📦 **4. 注文ステータス画面（進捗管理）（Day 5）**

#### ✅ **実装内容**
```dart
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
          if (!snapshot.hasData) return CircularProgressIndicator();
          
          var order = snapshot.data!.data() as Map<String, dynamic>;
          
          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 配送ステータス表示
                _buildStatusIndicator(order['status']),
                
                SizedBox(height: 20),
                
                // 注文詳細
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('注文ID: ${order['id']}'),
                        Text('配送先: ${order['address']}'),
                        Text('物資: ${order['items'].join(", ")}'),
                        Text('配送者: ${order['delivery_person_name']}'),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // 通知ボタン
                if (order['status'] == 'in_progress')
                  ElevatedButton(
                    onPressed: () => _sendNotificationToDelivery(),
                    child: Text('配送者に連絡'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

#### ✅ **実装内容**
```dart
class DetailScreen extends StatelessWidget {
  final DeliveryRequest request;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('配送詳細')),
      body: Column(
        children: [
          // Google Map表示（マーカー1個）
          Container(
            height: 300,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: request.location,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('delivery'),
                  position: request.location,
                ),
              },
            ),
          ),
          
          // 詳細情報
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text('場所: ${request.locationName}'),
                Text('物資: ${request.items.join(", ")}'),
                Text('距離: ${request.distance}km'),
                Text('効率スコア: ${request.score}点'),
                
                // ボタン
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _acceptDelivery(),
                      child: Text('配送受諾'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('拒否'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

### 📦 **3. 配送画面（Day 4）**

#### ✅ **実装内容**
```dart
class DeliveryScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('配送実行')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // ステータス表示
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('配送先: ${currentDelivery.location}'),
                    Text('距離: ${currentDelivery.distance}km'),
                    Text('予想時間: ${_calculateTime()}分'),
                    Text('進行状況: ${deliveryStatus}'),
                  ],
                ),
              ),
            ),
            
            // 完了ボタン
            ElevatedButton(
              onPressed: () => _completeDelivery(),
              child: Text('配送完了'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🧮 **簡単なアルゴリズム実装**

### 📊 **1. 効率スコア計算（if-else文）**

```dart
class ScoreCalculator {
  static double calculateScore(DeliveryRequest request) {
    double score = 70.0; // 基準点
    
    // 距離による減点
    if (request.distance > 5.0) {
      score -= 10.0;
    } else if (request.distance > 2.0) {
      score -= 5.0;
    }
    
    // 緊急度による加点
    if (request.isUrgent) {
      score += 20.0;
    } else if (request.priority == 'high') {
      score += 10.0;
    }
    
    // 天候による減点（固定値）
    if (Weather.isRaining) {
      score -= 5.0;
    }
    
    // 物資量による調整
    if (request.items.length > 3) {
      score -= 5.0;
    }
    
    return score.clamp(0.0, 100.0);
  }
}
```

### 🗺️ **2. 距離計算（直線距離）**

```dart
class DistanceCalculator {
  static double calculateDistance(LatLng start, LatLng end) {
    // Geolocatorパッケージ使用
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    ) / 1000; // メートルをkmに変換
  }
  
  static int estimateTime(double distanceKm) {
    // 1kmあたり3分で計算
    int baseTime = (distanceKm * 3).round();
    int trafficBuffer = 10; // 交通渋滞バッファ
    return baseTime + trafficBuffer;
  }
}
```

### 💾 **3. データ保存（SharedPreferences）**

```dart
class DeliveryStorage {
  static const String historyKey = 'delivery_history';
  
  static Future<void> saveDelivery(Delivery delivery) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(historyKey) ?? [];
    
    // JSON形式で保存
    history.add(jsonEncode(delivery.toMap()));
    await prefs.setStringList(historyKey, history);
  }
  
  static Future<List<Delivery>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(historyKey) ?? [];
    
    return history
        .map((json) => Delivery.fromMap(jsonDecode(json)))
        .toList();
  }
}
```

---

## 📅 **8日間開発スケジュール**

| 日 | 作業内容 | 成果物 | 時間 |
|----|----------|--------|------|
| **Day 1** | 環境構築・Flutter基本UI | ホーム画面レイアウト | 8h |
| **Day 2** | リスト表示・画面遷移 | ホーム画面完成 | 8h |
| **Day 3** | 詳細画面・地図表示 | 詳細画面完成 | 8h |
| **Day 4** | 配送画面・基本ロジック | 配送画面完成 | 8h |
| **Day 5** | スコア計算・データ保存 | 機能実装完了 | 8h |
| **Day 6** | テスト・バグ修正 | アプリ完成 | 8h |
| **Day 7** | UI調整・デモ準備 | デモ版完成 | 8h |
| **Day 8** | プレゼン準備・練習 | 発表準備完了 | 8h |

**合計**: 64時間（8日 × 8時間）

---

## 🎯 **3分間プレゼン構成**

### ⏰ **時間配分とスクリプト**

#### **0:00-0:30（30秒）問題提起**
```
「災害時の配送は混乱しやすく、配送員の判断に頼りがちです。
効率的な配送支援が必要だと考え、8日間でサポートアプリを開発しました。」
```

#### **0:30-2:00（90秒）アプリデモ**
```
「実際の操作をご覧ください。
ホーム画面で配送要請一覧を確認→スコア70点の要請をタップ→
詳細画面で地図と情報を確認、効率判定で受諾判断→
配送画面で実行、距離3.2km・予想時間20分と表示→配送完了。
シンプルな3画面で配送をサポートします。」
```

#### **2:00-2:45（45秒）技術説明**
```
「アルゴリズムは距離・緊急度・天候の3要素で効率スコアを計算。
if-else文の簡単なロジックですが、人的判断ミスを防げます。
Flutter + ローカルデータで8日間で完成しました。」
```

#### **2:45-3:00（15秒）まとめ**
```
「シンプルな構成ながら、災害時の配送効率化に貢献。
今後はリアルタイム機能やAI最適化で更なる改善を目指します。」
```

---

## 📊 **現実的な効果目標**

### ✅ **実現可能な効果**
- **判断時間短縮**: 要請確認 5分 → 2分（60%短縮）
- **判断精度向上**: スコア表示により客観的判断
- **操作簡便性**: 3タップで配送受諾可能
- **履歴管理**: 過去配送の記録・振り返り

### 📈 **測定可能な指標**
- 画面遷移時間（1秒以内）
- スコア計算時間（0.1秒以内）
- アプリ起動時間（3秒以内）
- 操作学習時間（10分以内）

---

## 🎯 **発表での強み**

### 💪 **アピールポイント**
1. **実用性重視**: 複雑な機能より使いやすさ優先
2. **短期開発**: 8日間で完成する現実的設計
3. **理解しやすさ**: 誰でも分かるシンプルなロジック
4. **拡張性**: 基本構造を維持して機能追加可能

### 🗣️ **想定質問への回答**

**Q: 「なぜこんなにシンプルなの？」**
A: 「災害時は操作の簡単さが最重要。複雑な機能より確実に動く基本機能を優先しました」

**Q: 「AIは使ってないの？」**
A: 「基本的な条件分岐でも十分効果があります。まず動くものを作り、段階的に高度化する方針です」

**Q: 「8日間で本当に作れる？」**
A: 「実際にこのアプリを8日間で開発しました。シンプルな設計により実現可能です」

---

## 🏆 **成功基準**

### ✅ **技術的成功**
- 3画面がスムーズに動作
- 基本的なスコア計算が機能
- データの保存・読み込みが動作
- エラーなく配送完了まで操作可能

### 🎤 **プレゼン成功**
- 3分以内で要点を説明
- デモが順調に動作
- 質問に的確に回答
- 聴衆に価値を伝達

この現実的なアーキテクチャにより、**8日間で完成し、3分間で魅力的にプレゼンできる**実用的なアプリが開発できます。