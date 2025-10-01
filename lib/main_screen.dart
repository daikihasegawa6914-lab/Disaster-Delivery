import 'package:flutter/material.dart';
import 'delivery_map_screen.dart';
import 'shelter_screen.dart';

// 🏠 メインアプリ画面（タブナビゲーション）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DeliveryMapScreen(),
    const ShelterScreen(),
    // 将来的に統計画面や設定画面を追加予定
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining),
            label: '配達マップ',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.location_city),
            label: '避難所情報',
          ),
          // 将来的に追加
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.bar_chart),
          //   label: '統計',
          // ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.settings),
          //   label: '設定',
          // ),
        ],
      ),
    );
  }
}