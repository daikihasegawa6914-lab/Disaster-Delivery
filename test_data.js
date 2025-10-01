// 🧪 Firestore テストデータ作成用スクリプト
// Firebase Console で手動入力する際の参考データ

// テストデータ 1: 緊急要請
{
  "item": "薬（血圧の薬）",
  "name": "佐藤花子",
  "location": {
    "latitude": 35.6895,
    "longitude": 139.6917
  },
  "timestamp": "現在時刻",
  "status": "waiting",
  "priority": "high",
  "deliveryPersonId": null,
  "phone": "090-1111-2222"
}

// テストデータ 2: 通常要請
{
  "item": "パン 3個",
  "name": "山田次郎",
  "location": {
    "latitude": 35.6762,
    "longitude": 139.6503
  },
  "timestamp": "現在時刻",
  "status": "waiting", 
  "priority": "medium",
  "deliveryPersonId": null,
  "phone": "090-3333-4444"
}

// テストデータ 3: 低優先度要請
{
  "item": "お菓子",
  "name": "鈴木三郎",
  "location": {
    "latitude": 35.6635,
    "longitude": 139.7514
  },
  "timestamp": "現在時刻",
  "status": "waiting",
  "priority": "low", 
  "deliveryPersonId": null,
  "phone": null
}

// テストデータ 4: 配達中（動作確認用）
{
  "item": "お米 5kg",
  "name": "田中一郎",
  "location": {
    "latitude": 35.6581,
    "longitude": 139.7414
  },
  "timestamp": "現在時刻",
  "status": "delivering",
  "priority": "medium",
  "deliveryPersonId": "delivery_test123",
  "phone": "090-5555-6666"
}

// テストデータ 5: 完了済み（履歴確認用）
{
  "item": "野菜セット",
  "name": "伊藤美子",
  "location": {
    "latitude": 35.6785,
    "longitude": 139.7923
  },
  "timestamp": "現在時刻",
  "status": "completed",
  "priority": "medium",
  "deliveryPersonId": "delivery_test456",
  "phone": "090-7777-8888"
}