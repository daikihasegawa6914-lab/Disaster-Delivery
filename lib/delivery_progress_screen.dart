import 'package:flutter/material.dart';
import 'models.dart';
import 'services.dart';
import 'constants.dart';

// 🚚 配達進行状況画面
// 自分が担当中 (assigned / delivering) の案件一覧と完了操作をまとめて行う簡易ビュー
class DeliveryProgressScreen extends StatelessWidget {
  final String deliveryPersonId; // 呼び出し側で取得済みの自分ID
  final void Function(DeliveryRequest request)? onJumpToRequest;
  const DeliveryProgressScreen({super.key, required this.deliveryPersonId, this.onJumpToRequest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🚚 進行中の配達')),
      body: StreamBuilder<List<DeliveryRequest>>(
        stream: FirebaseService.getMyDeliveries(deliveryPersonId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          final data = snapshot.data ?? [];
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
                  onTap: () => _showDetail(context, r),
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
                        Text(r.priorityColor, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.item, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(_statusLabel(r.status), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        if (onJumpToRequest != null)
                          IconButton(
                            tooltip: 'マップで表示',
                            icon: const Icon(Icons.map, color: Colors.blueAccent),
                            onPressed: () => onJumpToRequest?.call(r),
                          ),
                        _buildAction(context, r) ?? const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case RequestStatus.assigned: return '配達前 (出発待ち)';
      case RequestStatus.delivering: return '配達中';
      case RequestStatus.completed: return '完了';
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

  void _showDetail(BuildContext context, DeliveryRequest r) {
    showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.item, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('状態: ${_statusLabel(r.status)}'),
            Text('依頼者: ${r.requesterName}'),
            if (r.deliveryPersonId != null) Text('担当: ${r.deliveryPersonId}'),
            const SizedBox(height: 16),
            if (r.status == RequestStatus.assigned)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseService.startDelivery(r.id, r.deliveryPersonId!);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('開始失敗: $e')));
                    }
                  },
                  child: const Text('🚀 配達開始'),
                ),
              )
            else if (r.status == RequestStatus.delivering)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseService.completeDelivery(r.id);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('完了失敗: $e')));
                    }
                  },
                  child: const Text('✅ 配達完了'),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
