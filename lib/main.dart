import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// 認証は一時凍結（指令1）。FirebaseAuth/Firestore の起動時プロフィール判定は撤去。
import 'firebase_options.dart';
import 'security/secure_error_handler.dart';
import 'security/optimized_firestore.dart';
// import 'firestore_initializer.dart'; // ルール厳格化後は初期テストデータ挿入を停止
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart';
import 'profile_setup_screen.dart';
import 'profile_edit_screen.dart';
import 'login_screen.dart';
import 'license_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  try {
    debugPrint('[BOOT] Firebase.initializeApp start');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[BOOT] Firebase.initializeApp done');
  } catch (e, st) {
    debugPrint('[BOOT][ERROR] Firebase init failed: $e\n$st');
  }
  
  // 🚀 Firestore最適化設定
  try {
    debugPrint('[BOOT] Firestore offline enable start');
    await OptimizedFirestoreConfig.enableOfflineSupport();
    debugPrint('[BOOT] Firestore offline enable done');
  } catch (e) {
    debugPrint('[BOOT][WARN] Firestore offline config failed: $e');
  }
  
  // � 匿名認証を必ず確立（Firestoreルール: request.auth != null 対応）
  await _ensureAnonymousAuth();
  debugPrint('[BOOT] Anonymous auth uid=${FirebaseAuth.instance.currentUser?.uid}');
  // 起動時 lastActiveAt をタッチ (プロフィールが既に存在する場合のみ)
  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('delivery_persons').doc(uid).get();
    if (doc.exists) {
      await FirebaseFirestore.instance.collection('delivery_persons').doc(uid).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[BOOT] lastActiveAt touched');
    }
  } catch (e) {
    debugPrint('[BOOT][WARN] lastActiveAt touch failed: $e');
  }
  
  // 配達員用アプリを起動
  runApp(const DeliveryApp());
}

// 匿名ログインを保証
Future<void> _ensureAnonymousAuth() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
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
      // 指令1: 起動時ユーザーフロー統一。AuthWrapper 廃止し、ローカル登録状態で分岐。
      home: const StartupFlowWrapper(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/profile_edit': (context) => const ProfileEditScreen(),
        '/login': (context) => const LoginScreen(),
        '/license': (context) => const LicenseScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// � 起動時フロー: SharedPreferences で delivery_person_id を確認
class StartupFlowWrapper extends StatefulWidget {
  const StartupFlowWrapper({super.key});

  @override
  State<StartupFlowWrapper> createState() => _StartupFlowWrapperState();
}

class _StartupFlowWrapperState extends State<StartupFlowWrapper> {
  Future<String?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPersonId();
  }

  Future<String?> _loadPersonId() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final id = prefs.getString('delivery_person_id');
      debugPrint('[FLOW] Loaded delivery_person_id=$id');
      return id;
    } catch (e) {
      debugPrint('[FLOW][ERROR] SharedPreferences load failed: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('初期化エラー: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.blue,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        final hasId = (snapshot.data != null && snapshot.data!.isNotEmpty);
        return hasId ? const MainScreen() : const ProfileSetupScreen();
      },
    );
  }
}