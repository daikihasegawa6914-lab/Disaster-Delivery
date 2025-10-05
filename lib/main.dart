// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'security/secure_error_handler.dart';
import 'security/optimized_firestore.dart';

// 画面遷移は GoRouter に一本化（実装は ui/root_router.dart 側）
import 'ui/root_router.dart' show createAppRouter;
import 'package:go_router/go_router.dart';

/// アプリ全体で参照したい時用（例：バックグラウンド処理からの遷移など）
late final GoRouter appRouter;

void main() {
  // ✅ ゾーンを最初に作って、その中で ensureInitialized / runApp を呼ぶ（Zone mismatch 対策）
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 🛡️ グローバルエラー捕捉
    SecureErrorHandler.setupGlobalErrorHandling();
    FlutterError.onError = (details) {
      SecureErrorHandler.logSecureError(
        operation: 'Flutter Framework',
        error: details.exceptionAsString(),
        level: SecurityLevel.error,
        stackTrace: details.stack,
      );
      FlutterError.dumpErrorToConsole(details);
    };

    // 🔥 Firebase 初期化
    try {
      debugPrint('[BOOT] Firebase.initializeApp start');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[BOOT] Firebase.initializeApp done');
    } catch (e, st) {
      debugPrint('[BOOT][ERROR] Firebase init failed: $e\n$st');
    }

    // 🗃️ Firestore オフライン最適化
    try {
      debugPrint('[BOOT] Firestore offline enable start');
      await OptimizedFirestoreConfig.enableOfflineSupport();
      debugPrint('[BOOT] Firestore offline enable done');
    } catch (e) {
      debugPrint('[BOOT][WARN] Firestore offline config failed: $e');
    }

    // 👤 匿名認証を必ず確立（ネット不通でも UI は起動し、裏で再試行）
    await _ensureAnonymousAuthWithRetry();

    // （任意）配達員プロフィールがある場合のみ lastActiveAt を軽くタッチ
    unawaited(_touchLastActive());

    // 🚦 GoRouter 構築（利用者/配達員の切り替えUIや起動フローは root_router.dart 側で）
    appRouter = createAppRouter();

    runApp(const DisasterDeliveryApp());
  }, (e, st) {
    SecureErrorHandler.logSecureError(
      operation: 'Uncaught Zone Error',
      error: e.toString(),
      level: SecurityLevel.error,
      stackTrace: st,
    );
    debugPrint('🔒 [ERROR] Uncaught: $e\n$st');
  });
}

/// 匿名サインインを軽いリトライ付きで保証（ネットワーク不安定時の開発体験改善）
/// 成功しなくても致命にはせず、UI を先に出してバックグラウンドで再試行。
Future<void> _ensureAnonymousAuthWithRetry() async {
  final auth = FirebaseAuth.instance;

  if (auth.currentUser != null) return;

  const maxAttempts = 3;
  var delay = const Duration(milliseconds: 400);

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await auth.signInAnonymously();
      debugPrint('[BOOT] Anonymous sign-in OK (attempt $attempt)');
      return;
    } catch (e, st) {
      debugPrint('[BOOT][WARN] Anonymous sign-in failed (attempt $attempt/$maxAttempts): $e');
      SecureErrorHandler.logSecureError(
        operation: 'Anonymous Sign-in',
        error: e.toString(),
        level: SecurityLevel.warning,
        stackTrace: st,
      );
      if (attempt == maxAttempts) {
        // ここでは落とさず UI を先に表示。後で静かに再試行する
        unawaited(_retryAnonymousSignInSilently());
        return;
      }
      await Future.delayed(delay);
      delay *= 2;
    }
  }
}

/// 起動後に静かに再試行（ネット復帰を想定）
Future<void> _retryAnonymousSignInSilently() async {
  await Future.delayed(const Duration(seconds: 5));
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
      debugPrint('[BOOT] Anonymous sign-in recovered');
    }
  } catch (_) {
    // さらに失敗しても無視（次回起動時にまた試みる）
  }
}

Future<void> _touchLastActive() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
    await FirebaseFirestore.instance.collection('delivery_persons').doc(uid).get();
    if (!doc.exists) return;

    await FirebaseFirestore.instance
        .collection('delivery_persons')
        .doc(uid)
        .update({
      'lastActiveAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[BOOT] lastActiveAt touched');
  } catch (e) {
    debugPrint('[BOOT][WARN] lastActiveAt touch failed: $e');
  }
}

class DisasterDeliveryApp extends StatelessWidget {
  const DisasterDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Disaster Delivery',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade100,
          foregroundColor: Colors.blue.shade800,
        ),
      ),
      // 旧 Navigator.named で落ちた時の画面（保険）
      builder: (context, child) {
        return LegacyNamedRouteBridge(
          child: _LegacyRouteGuard(child: child),
        );
      },
    );
  }
}

class _LegacyRouteGuard extends StatelessWidget {
  const _LegacyRouteGuard({required this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Banner(
      location: BannerLocation.topStart,
      message: 'GoRouter',
      color: Colors.blue.withOpacity(0.6),
      textStyle: const TextStyle(fontSize: 10, color: Colors.white),
      child: child ?? const SizedBox.shrink(),
    );
  }
}

/// ----- Legacy named-routes → GoRouter 橋渡し（保険） -----
/// 既存コードに `Navigator.pushNamed(...)` / `pushReplacementNamed(...)` が残っていても
/// ここで受け止めて `appRouter.go(...)` に転送する。
class LegacyNamedRouteBridge extends StatelessWidget {
  const LegacyNamedRouteBridge({super.key, required this.child});
  final Widget child;

  Route<dynamic> _buildEmptyRoute(String name) {
    // 実際の遷移は GoRouter に任せ、ここでは透明な空ページを積むだけ
    return PageRouteBuilder(
      settings: RouteSettings(name: name),
      opaque: false,
      barrierColor: null,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  void _forwardToGoRouter(String? name) {
    if (name == null) return;
    // 既知パスはそのまま go。未知はトップへ退避
    const known = <String>{
      '/login',
      '/profile/setup',
      '/courier/main',
      '/admin/upload',
    };
    if (known.contains(name)) {
      appRouter.go(name);
    } else {
      // named で渡ってきたが未登録 → トップへ
      appRouter.go('/courier/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      // `pushNamed*` が来ると onGenerateRoute が呼ばれる
      onGenerateRoute: (settings) {
        _forwardToGoRouter(settings.name);
        return _buildEmptyRoute(settings.name ?? '');
      },
      onUnknownRoute: (settings) {
        _forwardToGoRouter(settings.name);
        return _buildEmptyRoute(settings.name ?? '');
      },
      // 配下に本来のアプリをぶら下げる
      pages: [
        MaterialPage<void>(child: child),
      ],
      onPopPage: (route, result) => route.didPop(result),
    );
  }
}