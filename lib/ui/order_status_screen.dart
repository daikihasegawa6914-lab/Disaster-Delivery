// lib/ui/order_status_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

/// Firestore コレクション名（ユーザ要望: 名称は request のまま）
const String kRequestCollection = 'requests';

/// ステータス → 進捗インデックス定義
const List<String> kStatusOrder = <String>[
  'waiting',     // 受付中（配達員未確定）
  'assigned',    // 担当者が決定
  'picking',     // 物資集荷中
  'delivering',  // 配達中
  'delivered',   // 配達完了
  'canceled',    // キャンセル
];

int statusToStep(String? status) {
  final s = (status ?? '').toLowerCase();
  final idx = kStatusOrder.indexOf(s);
  return idx >= 0 ? idx : 0;
}

bool isTerminal(String? status) =>
    status == 'delivered' || status == 'canceled';

String statusLabel(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'waiting':
      return '受付中';
    case 'assigned':
      return '配達員が確定';
    case 'picking':
      return '物資を集荷中';
    case 'delivering':
      return '配達中';
    case 'delivered':
      return '配達完了';
    case 'canceled':
      return 'キャンセル';
    default:
      return '不明';
  }
}

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _ErrorScaffold(
        message: '認証ユーザーが見つかりません',
        onBackToMenu: () => context.go('/user/request'),
      );
    }

    // 自分の直近のアクティブな依頼を 1 件取得（完了/キャンセルは除外）
    final query = FirebaseFirestore.instance
        .collection(kRequestCollection)
        .where('uid', isEqualTo: uid)
        .where('status', whereIn: ['waiting', 'assigned', 'picking', 'delivering'])
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => snap.data() ?? {},
      toFirestore: (data, _) => data,
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/user/request');
            }
          },
        ),
        title: const Text('依頼ステータス'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorBody(
              message: '取得中にエラーが発生しました：${snap.error}',
              onRetry: () => {}, // StreamBuilder は自動再購読
            );
          }
          if (!snap.hasData) {
            return const _Loading();
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            // アクティブ依頼が無い → “注文がありません” + メニュー誘導
            return _EmptyOrder(
              onGoToMenu: () => context.go('/user/request'),
              onSeeShelters: () => context.go('/user/home'),
            );
          }

          final data = docs.first.data();
          final itemSummary = _toItemSummary(data['items']);
          final status = (data['status'] as String?)?.toLowerCase();
          final step = statusToStep(status);
          final isDone = isTerminal(status);

          return _OrderDetail(
            requestId: docs.first.id,
            status: statusLabel(status),
            stepIndex: step,
            isTerminal: isDone,
            itemName: itemSummary,
            shelterName: data['shelterName'] as String? ?? data['shelter'] as String?,
            priority: data['priority'] as String?,
            etaMinutes: (data['etaMinutes'] is int) ? data['etaMinutes'] as int : null,
            createdAt: _toDateTime(data['createdAt']),
            updatedAt: _toDateTime(data['updatedAt']),
            onContactCourier: () {
              // 実装任意: 配達員の連絡先を request ドキュメントに持つなら遷移/ダイアログへ
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('連絡機能は未実装です')),
              );
            },
            onGoToMap: () => context.go('/user/map'),
          );
        },
      ),
    );
  }

  DateTime? _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String? _toItemSummary(dynamic items) {
    if (items is List) {
      final parts = <String>[];
      for (final e in items) {
        if (e is Map) {
          final n = (e['name'] ?? '').toString();
          final q = int.tryParse('${e['quantity'] ?? '0'}') ?? 0;
          if (n.isNotEmpty) {
            parts.add(q > 0 ? '$n×$q' : n);
          }
        }
      }
      if (parts.isNotEmpty) return parts.join(', ');
    }
    return null;
  }
}

/// ====== UI パーツ ======

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.message, required this.onBackToMenu});
  final String message;
  final VoidCallback onBackToMenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('依頼ステータス')),
      body: _ErrorBody(message: message, onRetry: onBackToMenu),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('やり直す'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrder extends StatelessWidget {
  const _EmptyOrder({
    required this.onGoToMenu,
    required this.onSeeShelters,
  });

  final VoidCallback onGoToMenu;
  final VoidCallback onSeeShelters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: cs.outline),
            const SizedBox(height: 12),
            Text('注文がありません', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '必要な物資を依頼しましょう。メニューから作成できます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onGoToMenu,
              icon: const Icon(Icons.add_box),
              label: const Text('物資を依頼する（メニューへ）'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSeeShelters,
              icon: const Icon(Icons.house_rounded),
              label: const Text('避難所を登録/選択'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({
    required this.requestId,
    required this.status,
    required this.stepIndex,
    required this.isTerminal,
    this.itemName,
    this.shelterName,
    this.priority,
    this.etaMinutes,
    this.createdAt,
    this.updatedAt,
    required this.onContactCourier,
    required this.onGoToMap,
  });

  final String requestId;
  final String status;
  final int stepIndex;
  final bool isTerminal;

  final String? itemName;
  final String? shelterName;
  final String? priority;
  final int? etaMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final VoidCallback onContactCourier;
  final VoidCallback onGoToMap;

  @override
  Widget build(BuildContext context) {
    final steps = kStatusOrder.map(statusLabel).toList();
    final isCanceled = status == statusLabel('canceled');
    final isDelivered = status == statusLabel('delivered');

    // 進捗バーは LinearProgressIndicator とステップラベルの合わせ技で視認性UP
    final progress = (stepIndex.clamp(0, steps.length - 1)) / (steps.length - 1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('依頼ID: $requestId', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 上段：大きな進捗バー
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    for (int i = 0; i < steps.length; i++)
                      _StepDot(
                        label: steps[i],
                        active: i <= stepIndex,
                        dimmed: i > stepIndex,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatusBadge(
                  text: status,
                  color: isCanceled
                      ? Colors.red
                      : (isDelivered ? Colors.green : Colors.blue),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 概要
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _KV('物資', itemName ?? '—'),
                _KV('避難所', shelterName ?? '—'),
                _KV('優先度', (priority ?? '—').toUpperCase()),
                if (etaMinutes != null) _KV('到着目安', '$etaMinutes 分'),
                _KV('更新', updatedAt?.toString() ?? '—'),
                _KV('作成', createdAt?.toString() ?? '—'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // アクション
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onGoToMap,
                icon: const Icon(Icons.map),
                label: const Text('地図で確認'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onContactCourier,
                icon: const Icon(Icons.support_agent),
                label: const Text('配達員に連絡'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        if (isTerminal)
          Text(
            isCanceled ? 'この依頼はキャンセルされました' : '配達が完了しました。ご利用ありがとうございました。',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.active, this.dimmed = false});
  final String label;
  final bool active;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: active ? cs.primary : cs.outline,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: dimmed ? cs.outline : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withOpacity(.12),
        shape: StadiumBorder(side: BorderSide(color: color.withOpacity(.4))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(k, style: TextStyle(color: cs.outline))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}