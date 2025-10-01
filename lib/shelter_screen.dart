import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'models.dart';
import 'services.dart';

// 🏥 避難所一覧・地図表示画面
class ShelterScreen extends StatefulWidget {
  const ShelterScreen({super.key});

  @override
  State<ShelterScreen> createState() => _ShelterScreenState();
}

class _ShelterScreenState extends State<ShelterScreen> {
  GoogleMapController? _mapController;
  String _currentView = 'map'; // 'map' or 'list'
  bool _showOnlyAvailable = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏥 避難所情報'),
        backgroundColor: Colors.green.shade100,
        actions: [
          // 表示切り替えボタン
          IconButton(
            icon: Icon(_currentView == 'map' ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _currentView = _currentView == 'map' ? 'list' : 'map';
              });
            },
            tooltip: _currentView == 'map' ? 'リスト表示' : '地図表示',
          ),
          // フィルターボタン
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _showOnlyAvailable = value == 'available';
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('🏥 全ての避難所'),
              ),
              const PopupMenuItem(
                value: 'available',
                child: Text('🟢 利用可能のみ'),
              ),
            ],
          ),
        ],
      ),
      body: _currentView == 'map' ? _buildMapView() : _buildListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeShelterData,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add_location, color: Colors.white),
        tooltip: '避難所データを初期化',
      ),
    );
  }

  // 地図表示
  Widget _buildMapView() {
    return StreamBuilder<List<Shelter>>(
      stream: _showOnlyAvailable 
          ? ShelterService.getAvailableShelters()
          : ShelterService.getAllShelters(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('🔍 避難所情報を読み込み中...'),
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

        final shelters = snapshot.data ?? [];
        final markers = _createMarkersFromShelters(shelters);

        return Stack(
          children: [
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              markers: markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              initialCameraPosition: const CameraPosition(
                target: LatLng(35.681236, 139.767125), // 東京駅
                zoom: 12.0,
              ),
              zoomControlsEnabled: true,
            ),
            _buildShelterCounter(shelters.length),
          ],
        );
      },
    );
  }

  // リスト表示
  Widget _buildListView() {
    return StreamBuilder<List<Shelter>>(
      stream: _showOnlyAvailable 
          ? ShelterService.getAvailableShelters()
          : ShelterService.getAllShelters(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('❌ エラー: ${snapshot.error}'));
        }

        final shelters = snapshot.data ?? [];

        if (shelters.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('🏥 避難所情報がありません', style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                Text('右下のボタンで初期データを作成してください'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: shelters.length,
          itemBuilder: (context, index) {
            final shelter = shelters[index];
            return _buildShelterCard(shelter);
          },
        );
      },
    );
  }

  // 避難所カード
  Widget _buildShelterCard(Shelter shelter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Text(
                  shelter.statusIcon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shelter.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildOccupancyChip(shelter),
              ],
            ),
            const SizedBox(height: 8),
            
            // 住所
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    shelter.address,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 収容状況
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${shelter.currentOccupancy}/${shelter.capacity}人'),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: shelter.occupancyRate,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(shelter.occupancyColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 設備
            if (shelter.facilities.isNotEmpty)
              Wrap(
                spacing: 4,
                children: shelter.facilities.map((facility) {
                  return Chip(
                    label: Text(
                      facility,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.blue.shade50,
                  );
                }).toList(),
              ),
            
            const SizedBox(height: 12),
            
            // アクションボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOnMap(shelter),
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('地図で表示'),
                  ),
                ),
                const SizedBox(width: 8),
                if (shelter.contactPhone != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _callShelter(shelter.contactPhone!),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('連絡'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 収容状況チップ
  Widget _buildOccupancyChip(Shelter shelter) {
    String text;
    Color color;
    
    if (shelter.occupancyRate < 0.7) {
      text = '空きあり';
      color = Colors.green;
    } else if (shelter.occupancyRate < 0.9) {
      text = '残りわずか';
      color = Colors.orange;
    } else {
      text = 'ほぼ満員';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 避難所件数表示
  Widget _buildShelterCounter(int count) {
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '🏥 $count件の避難所',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 避難所からマーカーを作成
  Set<Marker> _createMarkersFromShelters(List<Shelter> shelters) {
    return shelters.map((shelter) {
      return Marker(
        markerId: MarkerId(shelter.id),
        position: LatLng(shelter.location.latitude, shelter.location.longitude),
        infoWindow: InfoWindow(
          title: '${shelter.statusIcon} ${shelter.name}',
          snippet: '${shelter.currentOccupancy}/${shelter.capacity}人 | ${shelter.address}',
        ),
        onTap: () => _showShelterDetail(shelter),
        icon: _getShelterMarkerIcon(shelter),
      );
    }).toSet();
  }

  // 避難所の状態に応じたマーカーアイコン
  BitmapDescriptor _getShelterMarkerIcon(Shelter shelter) {
    switch (shelter.status) {
      case 'open':
        if (shelter.occupancyRate < 0.7) {
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        } else if (shelter.occupancyRate < 0.9) {
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        } else {
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        }
      case 'full':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'closed':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  // 地図で避難所を表示
  void _showOnMap(Shelter shelter) {
    setState(() {
      _currentView = 'map';
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(shelter.location.latitude, shelter.location.longitude),
              zoom: 16.0,
            ),
          ),
        );
      }
    });
  }

  // 避難所詳細を表示
  void _showShelterDetail(Shelter shelter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${shelter.statusIcon} ${shelter.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildShelterCard(shelter),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  // 避難所に連絡
  void _callShelter(String phoneNumber) {
    // 実際の実装では url_launcher を使用
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📞 $phoneNumber に連絡')),
    );
  }

  // 避難所データを初期化
  Future<void> _initializeShelterData() async {
    try {
      await ShelterService.createInitialShelterData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 避難所データを作成しました')),
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
}