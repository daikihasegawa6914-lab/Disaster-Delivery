import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'security/secure_error_handler.dart';
import 'security/optimized_firestore.dart';
import 'firestore_initializer.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'delivery_map_screen.dart';

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
  
  // 🗄️ データベース初期化（初回のみ実行）
  try {
    await FirestoreInitializer.initializeDatabase();
  } catch (e) {
    print('🗄️ [INFO] データベースは既に初期化済み、またはオフライン: $e');
  }
  
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
      home: const AuthWrapper(), // 認証状態による画面切り替え
      routes: {
        '/login': (context) => const LoginScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/delivery_map': (context) => const DeliveryMapScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// 🔐 認証状態管理ラッパー
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 認証状態の確認中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.blue,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delivery_dining,
                    size: 80,
                    color: Colors.white,
                  ),
                  SizedBox(height: 20),
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    '🚚 災害配達員アプリ\n起動中...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 認証済みの場合
        if (snapshot.hasData && snapshot.data != null) {
          return const ProfileCheckWrapper();
        }

        // 未認証の場合はログイン画面
        return const LoginScreen();
      },
    );
  }
}

// 👤 プロフィール設定状態チェック
class ProfileCheckWrapper extends StatelessWidget {
  const ProfileCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginScreen();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('delivery_persons')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.blue,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // プロフィール設定済みの場合は配達マップ画面へ
        if (snapshot.hasData && snapshot.data!.exists) {
          return const DeliveryMapScreen();
        }

        // プロフィール未設定の場合は設定画面へ
        return const ProfileSetupScreen();
      },
    );
  }
}