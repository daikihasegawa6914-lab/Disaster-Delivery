import 'package:flutter/material.dart';
import 'models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services.dart';
import 'constants.dart';

// 🚚 配達進行状況画面
// 自分が担当中 (assigned / delivering) の案件一覧と完了操作をまとめて行う簡易ビュー
class DeliveryProgressScreen extends StatefulWidget {
  final String deliveryPersonId; // 呼び出し側で取得済みの自分ID
  final void Function(DeliveryRequest request)? onJumpToRequest;
  const DeliveryProgressScreen({super.key, required this.deliveryPersonId, this.onJumpToRequest});

  @override
  State<DeliveryProgressScreen> createState() => _DeliveryProgressScreenState();
}

class _DeliveryProgressScreenState extends State<DeliveryProgressScreen> {
  final Map<String, double?> _distanceCache = {};
  bool _fetchingDistances = false;
  GeoPoint? _currentGeo;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (_fetchingDistances) return;
    _fetchingDistances = true;
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      _currentGeo = GeoPoint(pos.latitude, pos.longitude);
    }
    if (mounted) setState(() {});
  }

  void _ensureDistances(List<DeliveryRequest> reqs) {
    if (_currentGeo == null) return; // 位置未取得
    for (final r in reqs) {
      if (_distanceCache.containsKey(r.id)) continue;
      final d = LocationService.calculateDistance(_currentGeo!, r.location);
      _distanceCache[r.id] = d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DeliveryRequest>>(
  stream: FirebaseService.getMyDeliveries(widget.deliveryPersonId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          final data = snapshot.data ?? [];
          _ensureDistances(data); // 一度で全件距離算出
          if (data.isEmpty) {
            return const Center(child: Text('担当中の配達はありません'));
          }
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final r = data[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: InkWell(
                  // カード全体タップでマップへフォーカス（従来の地図アイコン機能を吸収）
                  onTap: () => widget.onJumpToRequest?.call(r),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blueGrey.shade100),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0,1))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        _statusBadge(r),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(r.item, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      ),
                                      if (r.priority == RequestPriority.high)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text('🆘', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ),
                                    ],
                                  ),
                              const SizedBox(height: 4),
                              Text(_statusLabel(r.status), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        _distanceChip(r),
                        const SizedBox(width: 4),
                        _buildAction(context, r) ?? const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
  }

  String _statusLabel(String s) {
    switch (s) {
      case RequestStatus.assigned: return '配達前 (出発待ち)';
      case RequestStatus.delivering: return '配達中';
      default: return s;
    }
  }

  Widget? _buildAction(BuildContext context, DeliveryRequest r) {
    if (r.status == RequestStatus.assigned) {
      return TextButton(
        onPressed: () async {
          try {
            await FirebaseService.startDelivery(r.id, r.deliveryPersonId!);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配達開始しました')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('開始失敗: $e')));
          }
        },
        child: const Text('開始'),
      );
    }
    if (r.status == RequestStatus.delivering) {
      return TextButton(
        onPressed: () async {
          try {
            await FirebaseService.completeDelivery(r.id);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配達完了しました')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('完了失敗: $e')));
          }
        },
        child: const Text('完了'),
      );
    }
    return null;
  }

  // ステータス: 塗り色 / 優先度: 枠線色 に分離して色の混在を避けるシンプルバッジ
  Widget _statusBadge(DeliveryRequest r) {
    Color fill;
    IconData icon;
    switch (r.status) {
      case RequestStatus.assigned:
        fill = Colors.amber.shade600; icon = Icons.assignment_turned_in; break;
      case RequestStatus.delivering:
        fill = Colors.orange.shade600; icon = Icons.local_shipping; break;
      default:
        fill = Colors.blueGrey.shade400; icon = Icons.help_outline; break;
    }
    Color border;
    switch (r.priority) {
      case RequestPriority.high: border = Colors.redAccent; break;
      case RequestPriority.medium: border = Colors.amber.shade300; break;
      case RequestPriority.low: border = Colors.green.shade300; break;
      default: border = Colors.blueGrey.shade300; break;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _distanceChip(DeliveryRequest r) {
    final d = _distanceCache[r.id];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Text(
        d == null ? '— km' : '${d.toStringAsFixed(1)} km',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
  // 詳細シートはカードタップ→マップ移動に統合したため削除しました。
}
