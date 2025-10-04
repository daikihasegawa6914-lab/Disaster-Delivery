// 👶 Flutterのメイン機能を使うためのimport。
import 'package:flutter/material.dart';
// 👶 Firebaseのコア機能（認証・DBなど）を使うためのimport。
import 'package:firebase_core/firebase_core.dart';
// 👶 Firebase関連の設定・セキュリティ・画面遷移・認証・ローカル保存など、
// アプリの主要機能を使うためのimport群。
import 'firebase_options.dart'; // Firebaseの設定
import 'security/secure_error_handler.dart'; // エラーハンドリング
import 'security/optimized_firestore.dart'; // Firestore最適化
// import 'firestore_initializer.dart'; // テストデータ挿入（開発用）
import 'package:firebase_auth/firebase_auth.dart'; // 認証
import 'main_screen.dart'; // メイン画面
import 'profile_setup_screen.dart'; // プロフィール初期登録
import 'profile_edit_screen.dart'; // プロフィール編集
import 'login_screen.dart'; // ログイン
import 'license_screen.dart'; // ライセンス情報
import 'package:shared_preferences/shared_preferences.dart'; // ローカル保存
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore

/// 👶 main関数: アプリの起動処理全体を担当。
/// - Flutterの初期化、Firebaseの初期化、セキュリティ設定、Firestoreの最適化、匿名認証、
///   ユーザーの最終活動記録、そしてアプリ本体の起動まで一連の流れを制御。
void main() async {
  // Flutterの初期化（非同期処理のため必須）
  WidgetsFlutterBinding.ensureInitialized();

  // グローバルエラーハンドリング（全画面で安全なエラー管理）
  SecureErrorHandler.setupGlobalErrorHandling();

  // セキュリティログ（初期化の記録）
  SecureErrorHandler.logSecureError(
    operation: 'App Initialization',
    error: 'アプリケーション開始',
    level: SecurityLevel.info,
  );

  // Firebase初期化（各種サービス利用のため）
  try {
    debugPrint('[BOOT] Firebase.initializeApp start');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[BOOT] Firebase.initializeApp done');
  } catch (e, st) {
    debugPrint('[BOOT][ERROR] Firebase init failed: $e\n$st');
  }

  // Firestoreのオフライン対応（災害時でもデータ利用可能）
  try {
    debugPrint('[BOOT] Firestore offline enable start');
    await OptimizedFirestoreConfig.enableOfflineSupport();
    debugPrint('[BOOT] Firestore offline enable done');
  } catch (e) {
    debugPrint('[BOOT][WARN] Firestore offline config failed: $e');
  }

  // 匿名認証（ユーザー識別・セキュリティルール対応）
  await _ensureAnonymousAuth();
  debugPrint('[BOOT] Anonymous auth uid=${FirebaseAuth.instance.currentUser?.uid}');

  // 起動時にユーザーの最終活動日時を記録（既存プロフィールのみ）
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

  // アプリ本体の起動（DeliveryAppウィジェット）
  runApp(const DeliveryApp());
}

/// 👶 匿名認証を保証する関数。
/// - Firebase AuthのcurrentUserがnullなら、匿名ログインを実行。
Future<void> _ensureAnonymousAuth() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
}

/// 👶 DeliveryAppクラス: アプリ全体のUIテーマ・ルート・初期画面を定義。
/// - Material Design 3をベースにしたテーマ設定。
/// - 画面遷移（routes）を一元管理。
/// - 初期画面はStartupFlowWrapperでユーザー登録状況に応じて分岐。
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
      // 起動時のユーザーフロー分岐（登録済みかどうかで画面切替）
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

/// 👶 StartupFlowWrapper: 起動時のユーザーフロー分岐を担当するウィジェット。
/// - SharedPreferencesでローカル保存された配達員IDを取得。
/// - IDがあればメイン画面、なければプロフィール設定画面へ遷移。
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

  /// 👶 ローカルストレージから配達員IDを取得する非同期関数。
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
        // 👶 エラー時は赤文字でエラー表示。
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('初期化エラー: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            ),
          );
        }
        // 👶 初期化中は青背景＋白インジケーター。
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.blue,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        // 👶 ID有無で画面分岐。
        final hasId = (snapshot.data != null && snapshot.data!.isNotEmpty);
        return hasId ? const MainScreen() : const ProfileSetupScreen();
      },
    );
  }
}

// 👶 このファイルはアプリのエントリーポイント（起動処理）です。
// - Firebase初期化やグローバルエラーハンドリング、画面遷移の設定を行います。
// - メインのウィジェットツリーは [DeliveryApp] で、テーマやルートの設定を行います。
// - 起動時に [StartupFlowWrapper] が表示され、ユーザーの登録状況に応じて適切な画面に遷移します。
// - Firebase Auth を使用して匿名認証を行い、ユーザーの識別を可能にします。
// - Firestore の最適化設定を行い、オフラインでもアプリが動作するようにします。
// - エラーハンドリングには [SecureErrorHandler] を使用し、セキュリティログを記録します。
// - アプリの初期化中にエラーが発生した場合、赤い文字でエラーメッセージを表示します。
// - 初期化中は青い背景に白い回転ローディングインジケーターを表示します。
// - 初期化が完了すると、ローカルストレージから配達員IDを読み込み、存在すればメイン画面へ、なければプロフィール設定画面へ遷移します。
// - メイン画面では、アプリの主要な機能である配達員のダッシュボードが表示されます。
// - プロフィール設定画面では、配達員のプロフィール情報を登録・編集することができます。
// - ログイン画面では、既存のユーザーがアプリにログインすることができます。
// - ライセンス画面では、アプリの利用規約やプライバシーポリシーなどの情報が表示されます。
// - 画面遷移は、ルート名を指定して簡単に行うことができ、コードの可読性が向上しています。