/// アプリ全体で共有する定数定義 (指令2)
/// 状態や優先度などの文字列を集中管理し、ヒューマンエラーを防止。
class RequestStatus {
  static const String waiting = 'waiting';
  static const String assigned = 'assigned';
  static const String delivering = 'delivering';
  static const String completed = 'completed';
}

class RequestPriority {
  static const String high = 'high';
  static const String medium = 'medium';
  static const String low = 'low';
}

/// Firestore フィールド名の集中定義 (変更耐性向上)
class FirestoreFields {
  static const String status = 'status';
  static const String priority = 'priority';
  static const String completedAt = 'completedAt';
  static const String assignedAt = 'assignedAt';
  static const String deliveryPersonId = 'deliveryPersonId';
  static const String updatedAt = 'updatedAt';
  static const String creatorUid = 'creatorUid';
  static const String timestamp = 'timestamp';
  static const String itemName = 'itemName';
  static const String requesterName = 'requesterName';
  static const String shelterId = 'shelterId';
}

/// 管理者 UID 一覧（最小実装: ハードコード）
class AdminConfig {
  static const Set<String> adminUids = {
    'PiOkqKfGXDPfqzLnm7WTI8Abvcl2', // 初期管理者
  };
}
