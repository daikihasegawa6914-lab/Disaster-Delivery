import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'security/secure_error_handler.dart';
import 'security/optimized_firestore.dart';
import 'delivery_map_screen.dart'; // 一時的にマップ画面を直接使用

void main() async {
  // 👶 簡単に言うと：「アプリを始める前の準備」
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🛡️ グローバルエラーハンドリング設定
  SecureErrorHandler.setupGlobalErrorHandling();
  
  // 🔐 セキュリティログ
  SecureErrorHandler.logSecureError(
    operation: 'App Initialization',
    error: 'アプリケーション開始',
    level: SecurityLevel.info,
  );
  
  // Firebaseに接続（既存の設定を使用）
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🚀 Firestore最適化設定
  await OptimizedFirestoreConfig.enableOfflineSupport();
  
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
      home: const DeliveryMapScreen(), // セキュリティ強化済み配達マップ画面
      debugShowCheckedModeBanner: false,
    );
  }
}