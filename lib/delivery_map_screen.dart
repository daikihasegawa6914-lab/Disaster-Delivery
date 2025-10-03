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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> moveCameraTo(LatLng latLng, {double zoom = 15}) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: zoom)));
  }

  Future<void> _init() async {
    debugPrint('[MAP] init start');
    // 避難所ストリーム購読（open のみ）
    _shelterSub = ShelterService.getAvailableShelters().listen((data) {
      if (mounted) setState(() => _shelters = data);
    });
    // 一度だけシード実行（許可ルールがある場合のみ）
    try {
      await ShelterService.seedProvidedSheltersIfMissing();
    } catch (e) {
      debugPrint('[SEED][WARN] shelter seed failed: $e');
    }
    await _loadPersonId();
    debugPrint('[MAP] personId=$_personId');
    await _moveToCurrentLocation();
    if (mounted) setState(() {});
    debugPrint('[MAP] init done');
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
    final Stream<List<DeliveryRequest>> stream = _currentView == 'emergency'
        ? FirebaseService.getEmergencyRequests()
        : FirebaseService.getWaitingRequests();

    return StreamBuilder<List<DeliveryRequest>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          debugPrint('[MAP][ERROR] stream: ${snap.error}');
          return Center(child: Text('❌ ${snap.error}'));
        }
        final requests = snap.data ?? [];
        debugPrint('[MAP] requests len=${requests.length}');
        final markers = requests.map(_markerFromRequest).toSet();
        final map = GoogleMap(
          onMapCreated: (c) {
            _mapController = c;
            debugPrint('[MAP] map created');
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // 重複するデフォルト現在地ボタンを非表示
          zoomControlsEnabled: false,
          initialCameraPosition: const CameraPosition(
            target: LatLng(35.681236, 139.767125),
            zoom: 12,
          ),
          markers: markers,
        );
        // 緊急件数バッジ用ストリーム（高優先度 waiting）
        return Stack(
          children: [
            map,
            Positioned(
              top: 8,
              left: 8,
              child: StreamBuilder<List<DeliveryRequest>>(
                stream: FirebaseService.getEmergencyRequests(),
                builder: (context, es) {
                  final cnt = es.data?.length ?? 0;
                  if (cnt == 0) return const SizedBox.shrink();
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text('🆘 緊急: $cnt件', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Marker _markerFromRequest(DeliveryRequest r) {
    // マーカー色: waiting=赤, assigned/delivering=青, completed=緑
    double hue;
    if (r.status == RequestStatus.waiting) {
      hue = BitmapDescriptor.hueRed;
    } else if (r.status == RequestStatus.completed) {
      hue = BitmapDescriptor.hueGreen;
    } else { // assigned / delivering
      hue = BitmapDescriptor.hueBlue;
    }

    final shelter = _findShelterForRequest(r);
    final snippet = shelter != null ? '🏥 ${shelter.name} / ${r.status}' : r.status;

    return Marker(
      markerId: MarkerId(r.id),
      position: LatLng(r.location.latitude, r.location.longitude),
      infoWindow: InfoWindow(title: '${r.priorityColor} ${r.item}', snippet: snippet),
      onTap: () {
        moveCameraTo(LatLng(r.location.latitude, r.location.longitude), zoom: 17);
        _showDetail(r);
      },
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
    );
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