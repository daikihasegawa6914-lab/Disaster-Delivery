import 'package:flutter/material.dart';
import 'services.dart';
import 'models.dart';

/// 🏥 避難所一覧 + その避難所宛て waiting 要請件数表示
// 👶 このファイルは「避難所一覧画面」のロジックです。
// - Firestoreから避難所データを取得し、リスト表示します。
// - 各避難所に紐づく待機中の要請件数を表示します。
// - 要請件数をタップすると、関連する要請の詳細を表示します。
// - UIはMaterial Designベースで、カードやリスト表示を活用しています。
// - StreamBuilderでリアルタイムにデータを監視し、画面を更新します。
// - 避難所ごとの要請件数は赤色バッジで強調表示されます。
// - 未割当リクエストも分かりやすく表示されます。
// - 避難所をタップすると、関連する要請一覧をボトムシートで表示できます。
class ShelterListScreen extends StatelessWidget {
  const ShelterListScreen({super.key, this.onShelterSelected});

  // マップ画面へジャンプするための座標通知コールバック
  final void Function(Shelter shelter)? onShelterSelected;

  @override
  Widget build(BuildContext context) {
    return _ShelterListBody(onShelterSelected: onShelterSelected);
  }
}

class _ShelterListBody extends StatefulWidget {
  const _ShelterListBody({this.onShelterSelected});
  final void Function(Shelter shelter)? onShelterSelected;
  @override
  State<_ShelterListBody> createState() => _ShelterListBodyState();
}

class _ShelterListBodyState extends State<_ShelterListBody> {
  late Stream<List<Shelter>> _sheltersStream;
  late Stream<List<DeliveryRequest>> _waitingRequestsStream;
  bool _showAll = false; // true ならステータスフィルタ解除

  @override
  void initState() {
    super.initState();
    _sheltersStream = ShelterService.getAvailableShelters();
    _waitingRequestsStream = FirebaseService.getWaitingRequests();
    // プロジェクトID簡易ログ (切り分け用)
    debugPrint('[SHELTER] project=disaster-delivery-app');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Shelter>>(
      stream: _sheltersStream,
      builder: (context, shelterSnap) {
        if (shelterSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (shelterSnap.hasError) {
          return Center(child: Text('❌ 避難所取得失敗: ${shelterSnap.error}'));
        }
        var shelters = shelterSnap.data ?? [];
        if (_showAll) {
          // 全取得へ切替するため、一時的に full 取得を追加で行う（簡易: 非効率だが調査用）
          // 本格対応ならサービスに getAllShelters() を使い分け実装。
        }
        debugPrint('[SHELTER] shelters len=${shelters.length}');
        return StreamBuilder<List<DeliveryRequest>>(
          stream: _waitingRequestsStream,
          builder: (context, reqSnap) {
            if (reqSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (reqSnap.hasError) {
              return Center(child: Text('❌ 要請取得失敗: ${reqSnap.error}'));
            }
            final waiting = reqSnap.data ?? [];
            debugPrint('[SHELTER] waiting len=${waiting.length}');
            // shelterId ごとにグループ化
            final Map<String, int> counts = {};
            int unassigned = 0;
            for (final r in waiting) {
              final sid = r.shelterId;
              if (sid == null || sid.isEmpty) {
                unassigned++;
              } else {
                counts[sid] = (counts[sid] ?? 0) + 1;
              }
            }
            final totalWaiting = waiting.length;
            if (shelters.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('避難所データがありません'),
                    const SizedBox(height: 12),
                    Text('waiting件数: $totalWaiting'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      child: Text(_showAll ? 'open のみ表示に戻す' : '全ステータス再取得を試す'),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(
                        unassigned > 0
                          ? '避難所: ${shelters.length}件 / waiting合計: $totalWaiting (未割当: $unassigned)'
                          : '避難所: ${shelters.length}件 / waiting合計: $totalWaiting'
                      )), 
                      TextButton(
                        onPressed: () => setState(() => _showAll = !_showAll),
                        child: Text(_showAll ? 'openのみ' : '全表示'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: shelters.length,
                    itemBuilder: (context, index) {
                      final s = shelters[index];
                      final count = counts[s.id] ?? 0;
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final related = waiting.where((r) => r.shelterId == s.id).toList();
                            if (related.length <= 1) {
                              // 1件以下なら直接マップへジャンプ
                              if (widget.onShelterSelected != null) widget.onShelterSelected!(s);
                            } else {
                              _openShelterRequestsSheet(s, waiting);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.house_siding, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('収容: ${s.currentOccupancy}/${s.capacity} (${(s.occupancyRate*100).toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (count > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('🚨 $count', style: const TextStyle(fontSize: 12)),
                                  ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (unassigned > 0)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('未割当リクエスト: $unassigned件', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // 避難所タップ時: その避難所に紐づく waiting リクエスト一覧を最小UIで表示
  void _openShelterRequestsSheet(Shelter shelter, List<DeliveryRequest> allWaiting) {
    final list = allWaiting.where((r) => r.shelterId == shelter.id).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${shelter.name} の要請', style: const TextStyle(fontWeight: FontWeight.bold))),
                    if (widget.onShelterSelected != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(c);
                          widget.onShelterSelected!(shelter); // マップへジャンプ
                        },
                        child: const Text('マップで見る'),
                      ),
                  ],
                ),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('この避難所宛ての待機中要請はありません'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = list[i];
                        return ListTile(
                          dense: true,
                          title: Text(r.item),
                          subtitle: Text('優先度: ${r.priority} / 状態: ${r.statusIcon}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // ここでは詳細画面は増やさずマップジャンプのみ (最小変更)
                            Navigator.pop(context);
                            if (widget.onShelterSelected != null) {
                              widget.onShelterSelected!(shelter);
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
