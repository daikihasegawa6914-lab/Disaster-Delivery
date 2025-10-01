import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'delivery_map_screen.dart'; // 配達員用地図画面

void main() async {
  // 👶 簡単に言うと：「アプリを始める前の準備」
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebaseに接続（友人のアプリと同じデータベースを使用）
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 配達員用アプリを起動
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🚚 災害配達員アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade100,
          foregroundColor: Colors.blue.shade800,
        ),
      ),
      home: const DeliveryMapScreen(), // 配達員は地図画面から開始
      debugShowCheckedModeBanner: false,
    );
  }
}