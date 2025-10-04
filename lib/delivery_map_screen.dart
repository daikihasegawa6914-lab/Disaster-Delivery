import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'services.dart';
import 'constants.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});
  static DeliveryMapScreenState? of(BuildContext context) => context.findAncestorStateOfType<DeliveryMapScreenState>();
  @override
  State<DeliveryMapScreen> createState() => DeliveryMapScreenState();
}

class DeliveryMapScreenState extends State<DeliveryMapScreen> {
  GoogleMapController? _mapController;
  String _currentView = 'all';
  String _personId = '';
  List<Shelter> _shelters = [];
  StreamSubscription<List<Shelter>>? _shelterSub;
  // マーカーアイコンキャッシュ
  BitmapDescriptor? _iconWaiting;
  BitmapDescriptor? _iconAssignedMine;
  BitmapDescriptor? _iconAssignedOthers;
  BitmapDescriptor? _iconDelivering;
  BitmapDescriptor? _iconCompleted;
  bool _openingSheet = false; // 連続タップガード

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> moveCameraTo(LatLng latLng, {double zoom = 15}) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: zoom)));
  }

  // 外部（進行中タブ）から特定リクエストへフォーカスし詳細を開く
  void focusOnRequest(DeliveryRequest r) {
    _openRequestDetail(r, fromExternal: true);
  }

  Future<void> _init() async {
    debugPrint('[MAP] init start');
    await _prepareMarkerIcons();
    // 避難所ストリーム購読（open のみ）
    _shelterSub = ShelterService.getAvailableShelters().listen((data) {
      if (mounted) setState(() => _shelters = data);
    });
    // シード機能は現在無効化（実運用/安定表示のため）
    // try {
    //   await ShelterService.seedProvidedSheltersIfMissing();
    // } catch (e) {
    //   debugPrint('[SEED][WARN] shelter seed failed: $e');
    // }
    await _loadPersonId();
    debugPrint('[MAP] personId=$_personId');
    await _moveToCurrentLocation();
    if (mounted) setState(() {});
    debugPrint('[MAP] init done');
  }

  // 状態別マーカー (簡易: defaultMarkerWithHue + alpha / hue の差 + 自分担当強調色)
  Future<void> _prepareMarkerIcons() async {
    _iconWaiting = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    // 自分担当 assigned: デフォ青より濃く表示 (hueBlue は 210° 相当 → 200° 近似で強調できないため同色 + later outline は未実装)
    _iconAssignedMine = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    // 他人担当 assigned: 薄青 (標準 blue)
    _iconAssignedOthers = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    _iconDelivering = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    _iconCompleted = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  @override
  void dispose() {
    _shelterSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPersonId() async {
    final prefs = await SharedPreferences.getInstance();
    _personId = prefs.getString('delivery_person_id') ?? '';
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      debugPrint('[LOC] requesting current location');
      final pos = await LocationService.getCurrentLocation().timeout(const Duration(seconds: 6), onTimeout: () {
        debugPrint('[LOC][TIMEOUT] fallback to default center');
        return null;
      });
      if (pos != null && _mapController != null) {
        debugPrint('[LOC] got position lat=${pos.latitude} lng=${pos.longitude}');
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 14),
          ),
        );
      }
    } catch (e) {
      debugPrint('[LOC][ERROR] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚚 配達マップ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _moveToCurrentLocation,
          ),
        ],
      ),
      body: _buildMapWithRequests(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _currentView = _currentView == 'emergency' ? 'all' : 'emergency'),
        backgroundColor: _currentView == 'emergency' ? Colors.red : Colors.orange,
        child: Icon(_currentView == 'emergency' ? Icons.warning : Icons.warning_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildMapWithRequests() {
    final Stream<List<DeliveryRequest>> waitingStream = _currentView == 'emergency'
        ? FirebaseService.getEmergencyRequests()
        : FirebaseService.getWaitingRequests();

    // まず waiting / emergency を取得し、その後 自分担当中(active) をネストしてマージ
    return StreamBuilder<List<DeliveryRequest>>(
      stream: waitingStream,
      builder: (context, waitingSnap) {
        if (waitingSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (waitingSnap.hasError) {
          debugPrint('[MAP][ERROR] waiting: ${waitingSnap.error}');
          return Center(child: Text('❌ ${waitingSnap.error}'));
        }
        final waiting = waitingSnap.data ?? [];

        // personId 未取得なら waiting のみ表示
        if (_personId.isEmpty) {
          return _buildMapStack(waiting, const []);
        }
        return StreamBuilder<List<DeliveryRequest>>(
          stream: FirebaseService.getMyDeliveries(_personId),
          builder: (context, mySnap) {
            if (mySnap.hasError) {
              debugPrint('[MAP][ERROR] my: ${mySnap.error}');
            }
            final mine = mySnap.data ?? [];
            return _buildMapStack(waiting, mine);
          },
        );
      },
    );
  }

  Widget _buildMapStack(List<DeliveryRequest> waiting, List<DeliveryRequest> mine) {
    // mine と waiting を統合（重複なし）
    final all = <DeliveryRequest>[]..addAll(waiting);
    final waitingIds = waiting.map((e) => e.id).toSet();
    for (final m in mine) {
      if (!waitingIds.contains(m.id)) all.add(m);
    }
    final markers = all.map(_markerFromRequest).toSet();

    final map = GoogleMap(
      onMapCreated: (c) {
        _mapController = c;
        debugPrint('[MAP] map created');
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: const CameraPosition(
        target: LatLng(35.681236, 139.767125),
        zoom: 12,
      ),
      mapToolbarEnabled: false, // 右下の経路/Googleマップショートカットを無効化
      markers: markers,
    );

    final waitingCount = waiting.length;
    final assignedCount = mine.where((e) => e.status == RequestStatus.assigned).length;
    final deliveringCount = mine.where((e) => e.status == RequestStatus.delivering).length;

    return Stack(
      children: [
        map,
        // 緊急バッジ
        Positioned(
          top: 8,
          left: 8,
          child: StreamBuilder<List<DeliveryRequest>>(
            stream: FirebaseService.getEmergencyRequests(),
            builder: (context, es) {
              final cnt = es.data?.length ?? 0;
              if (cnt == 0) return const SizedBox.shrink();
              return _badge('🆘 緊急: $cnt件', Colors.red.shade700);
            },
          ),
        ),
        // ステータスバー (中央上)
        Positioned(
          top: 8,
          right: 8,
          child: _statusBar(waitingCount, assignedCount, deliveringCount),
        ),
      ],
    );
  }

  Widget _statusBar(int waiting, int assigned, int delivering) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _countChip('待機', waiting, Colors.redAccent),
            const SizedBox(width: 6),
            _countChip('担当', assigned, Colors.blueAccent),
            const SizedBox(width: 6),
            _countChip('配達中', delivering, Colors.orangeAccent),
          ],
        ),
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label:$count'),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Marker _markerFromRequest(DeliveryRequest r) {
    // 状態 + 所有者でアイコン分岐
    BitmapDescriptor icon;
    if (r.status == RequestStatus.waiting) {
      icon = _iconWaiting ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else if (r.status == RequestStatus.completed) {
      icon = _iconCompleted ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (r.status == RequestStatus.delivering) {
      icon = _iconDelivering ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } else { // assigned
      if (r.deliveryPersonId == _personId && _personId.isNotEmpty) {
        icon = _iconAssignedMine ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      } else {
        icon = _iconAssignedOthers ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      }
    }


    return Marker(
      markerId: MarkerId(r.id),
      position: LatLng(r.location.latitude, r.location.longitude),
      // デフォルト InfoWindow を無効化して二度タップ問題を回避（空の InfoWindow を渡す）
      infoWindow: const InfoWindow(),
      onTap: () {
        _openRequestDetail(r);
      },
      icon: icon,
    );
  }

  void _openRequestDetail(DeliveryRequest r, {bool fromExternal = false}) async {
    if (_openingSheet) return; // 連打防止
    _openingSheet = true;

    try {
      // 位置が十分近い & ズームが既に高いならカメラアニメ省略
      final target = LatLng(r.location.latitude, r.location.longitude);
      bool needMove = true;
      if (_mapController != null) {
        final cameraPos = await _mapController!.getVisibleRegion();
        // 大雑把に対象が現在表示境界の内側なら移動省略
        if (target.latitude >= cameraPos.southwest.latitude &&
            target.latitude <= cameraPos.northeast.latitude &&
            target.longitude >= cameraPos.southwest.longitude &&
            target.longitude <= cameraPos.northeast.longitude) {
          needMove = false;
        }
      }

      if (needMove) {
        // 先に軽いハプティックで反応フィードバック
        // ignore: use_build_context_synchronously
        // HapticFeedback は platform channel を使うため import services が必要だが最小対応として try-catch で包む
        try { /* placeholder for future: HapticFeedback.lightImpact(); */ } catch (_) {}
        await moveCameraTo(target, zoom: 17);
      }

      if (!mounted) return;
      _showDetail(r);
    } finally {
      // 少し遅延してから解除 (シートアニメーション中の再タップ抑制)
      Future.delayed(const Duration(milliseconds: 300), () {
        _openingSheet = false;
      });
    }
  }

  Shelter? _findShelterForRequest(DeliveryRequest r) {
    if (_shelters.isEmpty) return null;
    // 1. shelterId 直接一致
    if (r.shelterId != null) {
      try {
        return _shelters.firstWhere((e) => e.id == r.shelterId);
      } catch (_) {}
    }
    // 2. 位置完全一致
    try {
      final exact = _shelters.firstWhere(
        (e) => e.location.latitude == r.location.latitude && e.location.longitude == r.location.longitude,
      );
      return exact;
    } catch (_) {}
    // 3. 近接一致（~20m 以内）
    const threshold = 0.0002; // 約 20m 目安
    for (final s in _shelters) {
      final dLat = (s.location.latitude - r.location.latitude).abs();
      final dLng = (s.location.longitude - r.location.longitude).abs();
      if (dLat < threshold && dLng < threshold) return s;
    }
    return null;
  }

  void _showDetail(DeliveryRequest r) {
    showModalBottomSheet(
      context: context,
      builder: (c) {
        final shelter = _findShelterForRequest(r);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.priorityColor, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.item, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Text(r.statusIcon, style: const TextStyle(fontSize: 24)),
                ],
              ),
              const SizedBox(height: 12),
              Text('状態: ${r.status}'),
              if (shelter != null) Text('避難所: ${shelter.name}'),
              Text('要請者: ${(r.requesterName.isEmpty ? null : r.requesterName) ?? '匿名さん'}'),
              if (r.phone != null) Text('連絡先: ${r.phone}'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text('経路案内'),
                  onPressed: () => _launchExternalNav(r.location.latitude, r.location.longitude, label: shelter?.name ?? r.item),
                ),
              ),
              const SizedBox(height: 8),
              // 競合 UI 制御判定
              if (((r.status == RequestStatus.assigned) || (r.status == RequestStatus.delivering)) && !(r.deliveryPersonId == _personId && _personId.isNotEmpty))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    '🚫 他の配達員が対応中です',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                )
              else if (r.status == RequestStatus.waiting)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.handshake),
                    label: const Text('🤝 この配達を引き受ける'),
                    onPressed: _personId.isEmpty ? null : () async {
                      try {
                        final navigator = Navigator.of(context);
                        await FirebaseService.assignDelivery(r.id, _personId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('配達を引き受けました')),
                          );
                        }
                        if (!mounted) return;
                        navigator.pop();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失敗: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                )
              else if (r.status == RequestStatus.assigned && r.deliveryPersonId == _personId)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.rocket_launch),
                        label: const Text('🚀 配達開始'),
                        onPressed: () async {
                          try {
                            final navigator = Navigator.of(context);
                            await FirebaseService.startDelivery(r.id, _personId);
                            if (!mounted) return;
                            navigator.pop();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失敗: $e')));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.undo),
                        label: const Text('引き受け解除'),
                        onPressed: () async {
                          try {
                            final navigator = Navigator.of(context);
                            await FirebaseService.cancelAssignment(r.id, _personId);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('引き受けを解除しました')));
                            navigator.pop();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失敗: $e')));
                          }
                        },
                      ),
                    ),
                  ],
                )
              else if (r.status == RequestStatus.delivering)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('✅ 配達完了'),
                    onPressed: () async {
                      try {
                        final navigator = Navigator.of(context);
                        await FirebaseService.completeDelivery(r.id);
                        if (!mounted) return;
                        navigator.pop();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失敗: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchExternalNav(double lat, double lng, {String? label}) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving&destination_place_id=&destination_name=${Uri.encodeComponent(label ?? '目的地')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('地図アプリを開けませんでした')));
    }
  }
}