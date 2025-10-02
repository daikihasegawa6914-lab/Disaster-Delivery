import 'package:flutter/material.dart';
import 'delivery_map_screen.dart';

// 🏠 メインアプリ画面（配達マップのみ）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    // 👶 配達員アプリでは配達マップのみ表示（タブナビゲーション削除）
    return const DeliveryMapScreen();
  }
}