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
}
