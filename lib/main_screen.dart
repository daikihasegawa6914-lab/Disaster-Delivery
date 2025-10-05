import 'package:flutter/material.dart';
import 'delivery_map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'shelter_list_screen.dart';
import 'delivery_progress_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 👶 このファイルは「メイン画面（タブナビゲーション）」のロジックです。
// - 配達マップ・進行状況・避難所一覧など複数画面をタブで切り替えられます。
// - 配達マップは Google Map を表示し、現在地やピンの操作が可能です。
// - 進行状況画面では、担当している配達の一覧と詳細を確認できます。
// - 避難所一覧画面では、避難所のリストを表示し、選択した避難所の位置に地図を移動できます。
// - 画面下部のナビゲーションバーで直感的に画面を切り替えられます。
// - プロフィール編集・ライセンス表示・ログアウトなどのメニューもAppBarから操作可能です。
// - 配達員の担当状況はフッターでリアルタイム表示され、UI/UXにも配慮した設計です。

// 🏠 メインアプリ画面（配達マップのみ）
/// 👶 MainScreen: アプリのメイン画面（タブナビゲーション）を管理するウィジェット。
/// - 配達マップ・進行状況・避難所一覧の3画面をタブで切り替え。
/// - 画面ごとに役割が分かれており、ユーザーが直感的に操作できる設計。
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// 👶 _MainScreenState: メイン画面の状態管理クラス。
/// - 現在のタブインデックスや配達員IDのキャッシュ、画面の初期化・切替を管理。
/// - 各画面（マップ・進行状況・避難所）をリストで保持し、タブ切替時に表示。
class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // 👶 現在表示中のタブインデックス（0:マップ, 1:進行中, 2:避難所）
  String? _deliveryPersonIdCache; // 👶 進行状況画面用の配達員IDキャッシュ
  bool _loadingId = true; // 👶 配達員ID取得中フラグ
  final GlobalKey<DeliveryMapScreenState> _mapKey = GlobalKey<DeliveryMapScreenState>(); // 👶 マップ画面の状態参照用キー

  List<Widget> _pages = const []; // 👶 各タブ画面のウィジェットリスト

  @override
  void initState() {
    super.initState();
    _initDriverId(); // 👶 起動時に配達員IDを取得
    _buildPages();   // 👶 画面リストを構築
  }

  /// 👶 ローカルストレージから配達員IDを取得し、画面リストを再構築。
  Future<void> _initDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('delivery_person_id');
    setState(() {
      _deliveryPersonIdCache = id ?? '';
      _loadingId = false;
      _buildPages();
    });
  }

  /// 👶 各タブ画面のウィジェットリストを構築。
  /// - マップ画面はDeliveryMapScreen。
  /// - 進行状況画面はDeliveryProgressScreen（配達員ID渡し、リクエスト選択でマップにジャンプ）。
  /// - 避難所一覧画面はShelterListScreen（避難所選択でマップにジャンプ）。
  void _buildPages() {
    final newPages = <Widget>[
      DeliveryMapScreen(key: _mapKey),
      _loadingId
          ? const Center(child: CircularProgressIndicator())
          : DeliveryProgressScreen(
              deliveryPersonId: _deliveryPersonIdCache ?? '',
              onJumpToRequest: (req) {
                setState(() => _currentIndex = 0);
                // 👶 マップ表示に切り替わった次フレームでリクエスト詳細にフォーカス
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapKey.currentState?.focusOnRequest(req);
                });
              },
            ),
      ShelterListScreen(
        onShelterSelected: (shelter) {
          setState(() => _currentIndex = 0);
          // 👶 マップ表示に切り替わった次フレームで避難所位置にカメラ移動
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapKey.currentState?.moveCameraTo(LatLng(shelter.location.latitude, shelter.location.longitude), zoom: 17);
          });
        },
      ),
    ];
    setState(() => _pages = newPages);
  }

  @override
  Widget build(BuildContext context) {
    // 👶 現在のタブに応じて画面を表示。IndexedStackで状態保持。
    final body = _pages.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : IndexedStack(index: _currentIndex, children: _pages);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? '🚚 配達マップ'
              : _currentIndex == 1
                  ? '📋 進行中リスト'
                  : '🏠 避難所一覧',
        ),
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade800,
        elevation: 2,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              tooltip: '現在地',
              icon: const Icon(Icons.my_location),
              onPressed: () => _mapKey.currentState?.moveCameraTo(const LatLng(35.681236, 139.767125), zoom: 14),
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                // 👶 プロフィール編集画面へ遷移。編集後はSnackBarで通知。
                final changed = await Navigator.of(context).pushNamed('/profile_edit');
                if (changed == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
                }
              } else if (v == 'logout') {
                // 👶 ログアウト処理（ID削除・匿名認証・ログイン画面へ遷移）
                await _handleLogout();
              } else if (v == 'license') {
                // 👶 ライセンス情報画面へ遷移
                if (mounted) Navigator.of(context).pushNamed('/license');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('🛠️ プロフィール編集')),
              PopupMenuItem(value: 'license', child: Text('📄 ライセンス / 出典')),
              PopupMenuItem(value: 'logout', child: Text('🚪 ログアウト')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (!_loadingId && (_deliveryPersonIdCache?.isNotEmpty ?? false))
            Positioned(
              left: 0,
              right: 0,
              bottom: kBottomNavigationBarHeight + 4,
              child: _DeliveryStatusFooter(deliveryPersonId: _deliveryPersonIdCache!),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '🗺️ マップ'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '進行中'),
          BottomNavigationBarItem(icon: Icon(Icons.home_work), label: '避難所一覧'),
        ],
      ),
    );
  }

  /// 👶 ログアウト処理。
  /// - 確認ダイアログ表示→ID削除→匿名認証→ログイン画面へ遷移。
  /// - メールアドレス未登録の場合は再ログイン不可なので注意。
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトすると再度ログインが必要です。メールアドレスとパスワードを登録しない場合、ログインはできません。続行しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('ログアウト')),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('delivery_person_id');
    await prefs.remove('delivery_person_name');
    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
    try { await FirebaseAuth.instance.signInAnonymously(); } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }
}

/// 👶 _DeliveryStatusFooter: 画面下部に配達員の担当状況をリアルタイム表示するウィジェット。
/// - StreamBuilderで担当件数・配達中件数を取得し、バッジ表示。
/// - 何も担当していない場合は非表示。
class _DeliveryStatusFooter extends StatelessWidget {
  final String deliveryPersonId;
  const _DeliveryStatusFooter({required this.deliveryPersonId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: FirebaseService.getMyStatusCounts(deliveryPersonId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;
        final assigned = data['assigned'] ?? 0;
        final delivering = data['delivering'] ?? 0;
        if (assigned + delivering == 0) {
          // 👶 何も担当していない時はフッター非表示
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                // 👶 マップ右上ステータスバーと差別化: 強めの青グラデ + 枠線
                gradient: LinearGradient(colors: [Colors.indigo.shade600, Colors.blue.shade400]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0,2))],
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.handshake, size: 16, color: Colors.amberAccent), const SizedBox(width:4), const Text('担当'), const SizedBox(width:2), Text('$assigned'),
                    const SizedBox(width: 12),
                    const Icon(Icons.local_shipping, size: 16, color: Colors.orangeAccent), const SizedBox(width:4), const Text('配達中'), const SizedBox(width:2), Text('$delivering'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}