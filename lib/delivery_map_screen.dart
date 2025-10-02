import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';
import 'services.dart';
import 'login_screen.dart';

// 🏠 シンプルな避難所マップ画面
class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  GoogleMapController? _mapController;
  String _currentView = 'all'; // 'all', 'emergency', 'my_deliveries'
  
  // 🔐 認証済みユーザーのIDを取得
  String get _deliveryPersonId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _moveToCurrentLocation();
  }

  // 現在地に地図を移動
  Future<void> _moveToCurrentLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14.0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚚 配達マップ'),
        backgroundColor: Colors.blue.shade100,
        actions: [
          // 現在地移動ボタン
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _moveToCurrentLocation,
            tooltip: '現在地に移動',
          ),
          // 表示切り替えメニュー
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _currentView = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('📋 全ての要請'),
              ),
              const PopupMenuItem(
                value: 'emergency',
                child: Text('🆘 緊急要請のみ'),
              ),
              const PopupMenuItem(
                value: 'my_deliveries',
                child: Text('🚚 担当中の配達'),
              ),
            ],
          ),
          // ログアウトボタン
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: _buildMapWithRequests(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 🆘 緑急要請フィルターボタン
          FloatingActionButton(
            heroTag: "emergency",
            onPressed: () {
              setState(() {
                _currentView = _currentView == 'emergency' ? 'all' : 'emergency';
              });
            },
            backgroundColor: _currentView == 'emergency' ? Colors.red : Colors.orange,
            child: Icon(
              _currentView == 'emergency' ? Icons.warning : Icons.warning_outlined,
              color: Colors.white,
            ),
            tooltip: _currentView == 'emergency' ? '全要請表示' : '緑急要請のみ',
          ),
          const SizedBox(height: 10),
          // 📍 現在地ボタン
          FloatingActionButton(
            heroTag: "location",
            onPressed: _moveToCurrentLocation,
            child: const Icon(Icons.my_location),
            tooltip: '現在地に移動',
          ),
        ],
      ),
    );
  }

  // 📋 要請一覧を表示
  void _showRequestsList(List<DeliveryRequest> requests) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '📋 要請一覧 (${requests.length}件)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getPriorityColor(request.priority),
                        child: Text(
                          request.priorityColor,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      title: Text(
                        request.item,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('👤 ${request.requesterName}'),
                          Text('⏰ ${_formatDateTime(request.timestamp)}'),
                        ],
                      ),
                      trailing: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.red,
                          ),
                          Text(
                            '移動',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _moveToRequest(request);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 📍 要請位置に地図を移動
  void _moveToRequest(DeliveryRequest request) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(request.location.latitude, request.location.longitude),
            zoom: 16.0,
          ),
        ),
      );
      
      // 少し待ってから詳細を表示
      Future.delayed(const Duration(milliseconds: 500), () {
        _showRequestDetail(request);
      });
    }
  }

  // 緊急度に応じた色を取得
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  // 日時フォーマット関数をクラスレベルに移動
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 🧪 テストデータメニューを表示
  void _showTestDataMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🧪 テストデータ管理',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // テストデータ作成ボタン
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                _showLoadingDialog(context, 'テストデータを作成中...');
                try {
                  // テストデータ作成機能は一時的に無効化
                  Navigator.pop(context); // ローディング閉じる
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ テストデータを作成しました')),
                  );
                } catch (e) {
                  Navigator.pop(context); // ローディング閉じる
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ エラー: $e')),
                  );
                }
              },
              icon: const Icon(Icons.add_circle),
              label: const Text('📝 テストデータを作成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 10),
            
            // データ状況確認ボタン
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                // データ状態確認機能は一時的に無効化
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📊 データ状況をログで確認してください')),
                );
              },
              icon: const Icon(Icons.info),
              label: const Text('📊 データ状況を確認'),
            ),
            
            const SizedBox(height: 10),
            
            // データ削除ボタン
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(context);
              },
              icon: const Icon(Icons.delete),
              label: const Text('🗑️ 全データ削除'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ローディングダイアログを表示
  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  // 削除確認ダイアログ
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 確認'),
        content: const Text('全てのテストデータを削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showLoadingDialog(context, 'データを削除中...');
              try {
                // テストデータ削除機能は一時的に無効化
                Navigator.pop(context); // ローディング閉じる
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ 全てのデータを削除しました')),
                );
              } catch (e) {
                Navigator.pop(context); // ローディング閉じる
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ エラー: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }

  // 選択された表示モードに応じて地図を構築
  Widget _buildMapWithRequests() {
    Stream<List<DeliveryRequest>> stream;
    
    switch (_currentView) {
      case 'emergency':
        stream = FirebaseService.getEmergencyRequests();
        break;
      case 'my_deliveries':
        stream = FirebaseService.getMyDeliveries(_deliveryPersonId);
        break;
      default:
        stream = FirebaseService.getWaitingRequests();
    }

    return StreamBuilder<List<DeliveryRequest>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('🔍 配達要請を検索中...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('❌ エラー: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('🔄 再試行'),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? [];
        
        if (requests.isEmpty) {
          return Stack(
            children: [
              _buildGoogleMap({}),
              _buildEmptyStateMessage(),
            ],
          );
        }

        // 要請をマーカーに変換
        final markers = _createMarkersFromRequests(requests);
        
        return Stack(
          children: [
            _buildGoogleMap(markers),
            _buildRequestCounter(requests.length, requests),
            _buildLocationTrackingStatus(), // 🛰️ 位置追跡ステータス
          ],
        );
      },
    );
  }

  // 空の状態のメッセージ
  Widget _buildEmptyStateMessage() {
    String message;
    switch (_currentView) {
      case 'emergency':
        message = '🎉 現在、緊急要請はありません';
        break;
      case 'my_deliveries':
        message = '📋 担当中の配達はありません';
        break;
      default:
        message = '📍 現在、配達要請はありません';
    }

    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // 要請件数表示（クリック可能）
  Widget _buildRequestCounter(int count, List<DeliveryRequest> requests) {
    return Positioned(
      top: 20,
      left: 20,
      child: GestureDetector(
        onTap: () => _showRequestsList(requests), // タップで一覧表示
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _getCounterColor(count),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getCounterText(count),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.list,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCounterColor(int count) {
    if (count == 0) return Colors.green;
    if (count <= 3) return Colors.orange;
    return Colors.red;
  }

  String _getCounterText(int count) {
    switch (_currentView) {
      case 'emergency':
        return '🆘 $count件の緊急要請';
      case 'my_deliveries':
        return '🚚 $count件配達中';
      default:
        return '📋 $count件の要請';
    }
  }

  // 位置追跡ステータスは表示しない（簡素化のため）
  Widget _buildLocationTrackingStatus() {
    return const SizedBox.shrink();
  }

  // 要請リストからマーカーを作成
  Set<Marker> _createMarkersFromRequests(List<DeliveryRequest> requests) {
    return requests.map((request) {
      return Marker(
        markerId: MarkerId(request.id),
        position: LatLng(request.location.latitude, request.location.longitude),
        infoWindow: InfoWindow(
          title: '${request.priorityColor} ${request.item}',
          snippet: '👤 ${request.requesterName} | ${request.statusIcon} ${request.status}',
        ),
        onTap: () => _showRequestDetail(request),
        icon: _getMarkerIcon(request),
      );
    }).toSet();
  }

  // 要請の状態に応じたマーカーアイコンを取得
  BitmapDescriptor _getMarkerIcon(DeliveryRequest request) {
    // 簡易版：色で区別
    switch (request.priority) {
      case 'high':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'medium':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 'low':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

    // Google Map ウィジェットを構築（配送員位置マーカーは表示しない）
    Widget _buildGoogleMap(Set<Marker> markers) {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        // 自動で現在地に移動しないように変更
        // _determinePosition(); // コメントアウト
      },
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false, // 独自のボタンを使用
      initialCameraPosition: const CameraPosition(
        target: LatLng(35.681236, 139.767125), // 東京駅
        zoom: 12.0,
      ),
      zoomControlsEnabled: true,
      zoomGesturesEnabled: true,
    );
  }

  // 要請の詳細を表示
  void _showRequestDetail(DeliveryRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RequestDetailSheet(
        request: request,
        onStartDelivery: () => _startDelivery(request),
        onCompleteDelivery: () => _completeDelivery(request),
      ),
    );
  }

  // 配達開始
  Future<void> _startDelivery(DeliveryRequest request) async {
    try {
      await FirebaseService.startDelivery(request.id, _deliveryPersonId);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🚀 ${request.item}の配達を開始しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ エラー: $e')),
        );
      }
    }
  }

  // 配達完了
  Future<void> _completeDelivery(DeliveryRequest request) async {
    try {
      await FirebaseService.completeDelivery(request.id);
      await FirebaseService.recordDeliveryStats(request.id, _deliveryPersonId);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${request.item}の配達が完了しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ エラー: $e')),
        );
      }
    }
  }

  // ログアウト機能 🛡️
  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ログアウトエラー: $e')),
        );
      }
    }
  }
}

// 要請詳細を表示するボトムシート
class _RequestDetailSheet extends StatelessWidget {
  final DeliveryRequest request;
  final VoidCallback onStartDelivery;
  final VoidCallback onCompleteDelivery;

  const _RequestDetailSheet({
    required this.request,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ヘッダー
          Row(
            children: [
              Text(
                request.priorityColor,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.item,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                request.statusIcon,
                style: const TextStyle(fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 詳細情報
          _buildInfoRow('👤 要請者', request.requesterName),
          _buildInfoRow('📍 状態', request.status),
          _buildInfoRow('⏰ 要請時刻', _formatDateTime(request.timestamp)),
          if (request.phone != null)
            _buildInfoRow('📞 連絡先', request.phone!),
          
          const SizedBox(height: 20),
          
          // アクションボタン
          if (request.status == 'waiting')
            ElevatedButton.icon(
              onPressed: onStartDelivery,
              icon: const Icon(Icons.play_arrow),
              label: const Text('🚀 配達を開始する'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            )
          else if (request.status == 'delivering')
            ElevatedButton.icon(
              onPressed: onCompleteDelivery,
              icon: const Icon(Icons.check),
              label: const Text('✅ 配達完了を報告'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          
          const SizedBox(height: 10),
          
          // 閉じるボタン
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}