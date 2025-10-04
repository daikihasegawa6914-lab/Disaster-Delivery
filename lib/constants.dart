// 👶 このファイルはアプリ全体で使う定数（色・文字列・キーなど）をまとめています。
// - 変更しやすく、複数画面で使い回せるように設計されています。
// - 定数を一箇所に集約することで、値の変更や管理が簡単になり、ヒューマンエラーを防止できます。
// - Firestoreのフィールド名やステータス値もここで定義し、コード全体の統一性を保っています。

/// 👶 RequestStatusクラス: 配達リクエストの状態を表す定数。
/// - FirestoreやUIで状態管理に使う文字列を一元管理。
/// - 文字列のスペルミスや値の不統一を防ぐため、必ずこの定数を使うこと。
class RequestStatus {
  static const String waiting = 'waiting'; // 処理待ち
  static const String assigned = 'assigned'; // 担当者決定
  static const String delivering = 'delivering'; // 配達中
  static const String completed = 'completed'; // 完了
}

/// 👶 RequestPriorityクラス: 配達リクエストの優先度を表す定数。
/// - FirestoreやUIで優先度管理に使う文字列を一元管理。
/// - 優先度によってUIの色分けや表示順序を制御する際にも利用。
class RequestPriority {
  static const String high = 'high'; // 高
  static const String medium = 'medium'; // 中
  static const String low = 'low'; // 低
}

/// 👶 FirestoreFieldsクラス: Firestoreのフィールド名を一元管理。
/// - DB設計変更時もここだけ修正すれば全体に反映される。
/// - フィールド名のスペルミスや不統一を防ぐため、必ずこの定数を使うこと。
class FirestoreFields {
  static const String status = 'status'; // ステータス
  static const String priority = 'priority'; // プライオリティ
  static const String completedAt = 'completedAt'; // 完了日時
  static const String assignedAt = 'assignedAt'; // 担当者決定日時
  static const String deliveryPersonId = 'deliveryPersonId'; // 配達者ID
  static const String updatedAt = 'updatedAt'; // 更新日時
  static const String creatorUid = 'creatorUid'; // 作成者UID
  static const String timestamp = 'timestamp'; // タイムスタンプ
  static const String itemName = 'itemName'; // アイテム名
  static const String requesterName = 'requesterName'; // 依頼者名
  static const String shelterId = 'shelterId'; // シェルターID
}

/// 👶 AdminConfigクラス: 管理者UIDの一覧を定義。
/// - 管理者専用機能のアクセス制御に利用。
/// - 本番運用ではDBや環境変数で管理することも推奨。
class AdminConfig {
  static const Set<String> adminUids = {
    'PiOkqKfGXDPfqzLnm7WTI8Abvcl2', // 初期管理者
  };
}
