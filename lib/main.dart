import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // flutterfire configure で生成されるやつ
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化（ここで失敗すると黒画面で落ちるので try/catch 付き）
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase init error: $e\n$st');
    // 初期化失敗時でもクラッシュさせずに起動
  }

  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Disaster Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Firebase initialized.';

  Future<void> _signInAnon() async {
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      setState(() => _status = 'Signed in (anon): ${cred.user?.uid}');
    } catch (e) {
      setState(() => _status = 'Sign-in failed: $e');
    }
  }

  Future<void> _requestLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _status = '位置情報サービスがオフです。');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() => _status = '位置情報の権限がありません。設定から許可してください。');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _status = '現在地: (${pos.latitude}, ${pos.longitude})');
    } catch (e) {
      setState(() => _status = '位置情報取得エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Disaster Delivery')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status),
            const SizedBox(height: 16),
            Text('Auth: ${user == null ? "未ログイン" : "ログイン中 (${user.uid})"}'),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _signInAnon,
                  icon: const Icon(Icons.login),
                  label: const Text('匿名ログイン'),
                ),
                OutlinedButton.icon(
                  onPressed: _requestLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('位置情報を取得'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'この画面は動作確認用の仮ホームです。\n'
                  '後で画面遷移（マップ/一覧/依頼作成など）に差し替えてOK。',
            ),
          ],
        ),
      ),
    );
  }
}