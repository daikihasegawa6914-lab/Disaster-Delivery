import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'services.dart';
import 'constants.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});
  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  GoogleMapController? _mapController;
  String _currentView = 'all';
  String _personId = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    debugPrint('[MAP] init start');
    await _loadPersonId();
    debugPrint('[MAP] personId=$_personId');
    await _moveToCurrentLocation();
    if (mounted) setState(() {});
    debugPrint('[MAP] init done');
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) => setState(() => _currentView = v),
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'all', child: Text('📋 全て')),
              PopupMenuItem(value: 'emergency', child: Text('🆘 緊急')),
            ],
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
        return GoogleMap(
          onMapCreated: (c) {
            _mapController = c;
            debugPrint('[MAP] map created');
          },
          myLocationEnabled: true,
          initialCameraPosition: const CameraPosition(
            target: LatLng(35.681236, 139.767125),
            zoom: 12,
          ),
          markers: markers,
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

    return Marker(
      markerId: MarkerId(r.id),
      position: LatLng(r.location.latitude, r.location.longitude),
      infoWindow: InfoWindow(title: '${r.priorityColor} ${r.item}', snippet: r.status),
      onTap: () => _showDetail(r),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
    );
  }

  void _showDetail(DeliveryRequest r) {
    showModalBottomSheet(
      context: context,
      builder: (c) {
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
              Text('要請者: ${r.requesterName}'),
              if (r.phone != null) Text('連絡先: ${r.phone}'),
              const SizedBox(height: 16),
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
}