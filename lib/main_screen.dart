import 'package:flutter/material.dart';
import 'delivery_map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'shelter_list_screen.dart';

// 🏠 メインアプリ画面（配達マップのみ）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<DeliveryMapScreenState> _mapKey = GlobalKey<DeliveryMapScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DeliveryMapScreen(key: _mapKey),
      ShelterListScreen(
        onShelterSelected: (shelter) {
          // タブをマップへ切替後、カメラ移動
          setState(() => _currentIndex = 0);
          // 遅延してから移動（タブ切替後にコントローラが存在）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapKey.currentState?.moveCameraTo(LatLng(shelter.location.latitude, shelter.location.longitude), zoom: 17);
          });
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '🗺️ マップ'),
          BottomNavigationBarItem(icon: Icon(Icons.home_work), label: '避難所一覧'),
        ],
      ),
    );
  }
}