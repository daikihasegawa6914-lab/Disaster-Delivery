import 'package:flutter/material.dart';
import 'delivery_map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'shelter_list_screen.dart';
import 'delivery_progress_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🏠 メインアプリ画面（配達マップのみ）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? _deliveryPersonIdCache; // 進行状況画面用
  bool _loadingId = true;
  final GlobalKey<DeliveryMapScreenState> _mapKey = GlobalKey<DeliveryMapScreenState>();

  List<Widget> _pages = const [];

  @override
  void initState() {
    super.initState();
    _initDriverId();
    _buildPages();
  }
  Future<void> _initDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('delivery_person_id');
    setState(() {
      _deliveryPersonIdCache = id ?? '';
      _loadingId = false;
      _buildPages();
    });
  }

  void _buildPages() {
    final newPages = <Widget>[
      DeliveryMapScreen(key: _mapKey),
      _loadingId
          ? const Center(child: CircularProgressIndicator())
          : DeliveryProgressScreen(
              deliveryPersonId: _deliveryPersonIdCache ?? '',
              onJumpToRequest: (req) {
                setState(() => _currentIndex = 0);
                // map 表示に切り替わった次フレームでフォーカス
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapKey.currentState?.focusOnRequest(req);
                });
              },
            ),
      ShelterListScreen(
        onShelterSelected: (shelter) {
          setState(() => _currentIndex = 0);
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
              tooltip: '現在地'
                  ,
              icon: const Icon(Icons.my_location),
              onPressed: () => _mapKey.currentState?.moveCameraTo(const LatLng(35.681236, 139.767125), zoom: 14),
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                final changed = await Navigator.of(context).pushNamed('/profile_edit');
                if (changed == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
                }
              } else if (v == 'logout') {
                await _handleLogout();
              } else if (v == 'license') {
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
          // 何も担当していない時は表示しない
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                // マップ右上ステータスバーと差別化: 強めの青グラデ + 枠線
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