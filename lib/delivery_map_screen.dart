// 👶 このファイルは「配達マップ画面」のロジックです。
// - Google Mapsと連携し、配達リクエストや避難所を地図上に表示します。
// - 配達員の現在地取得やマーカー表示、リクエストの引き受け・進行管理も行います。
// - 状態管理はsetStateとStreamBuilderでシンプルに実装されています。
// - マップ上のマーカーはリクエストの状態や担当者によって色分けされます。
// - ボトムシートで詳細表示や操作ができ、UI/UXにも配慮した設計です。
// - データ取得はFirebaseのストリームを活用し、リアルタイム更新に対応しています。

import 'package:flutter/material.dart';
// import 'dart:math' as Math; // 扇状オフセット利用を廃止
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'services.dart';
import 'constants.dart';

/// 👶 DeliveryMapScreen: 配達マップ画面のメインウィジェット。
/// - GoogleMapウィジェットを中心に、配達リクエストや避難所の情報を地図上に表示。
/// - 画面状態はStatefulWidgetで管理し、ユーザー操作やデータ更新に柔軟に対応。
class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});
  static DeliveryMapScreenState? of(BuildContext context) => context.findAncestorStateOfType<DeliveryMapScreenState>();
  @override
  State<DeliveryMapScreen> createState() => DeliveryMapScreenState();
}

/// 👶 DeliveryMapScreenState: マップ画面の状態管理クラス。
/// - GoogleMapControllerで地図操作。
/// - _currentViewで表示モード（全件/緊急）を切替。
/// - _personIdで現在の配達員IDを保持。
/// - _sheltersで避難所リストを管理。
/// - マーカーアイコンは状態ごとに色分けし、キャッシュで高速化。
/// - ボトムシートの多重操作防止や安全な閉じ方も工夫。
class DeliveryMapScreenState extends State<DeliveryMapScreen> {
  GoogleMapController? _mapController;
  String _currentView = 'all';
  String _personId = '';
  List<Shelter> _shelters = [];
  StreamSubscription<List<Shelter>>? _shelterSub;
  // マーカーアイコンキャッシュ
  BitmapDescriptor? _iconWaiting;
  BitmapDescriptor? _iconAssignedOthers;
  BitmapDescriptor? _iconDelivering;
  bool _openingSheet = false; // 連続タップガード
  bool _sheetActionRunning = false; // ボトムシート内操作の多重防止 & pop 安全化
  bool _pendingSheetClose = false; // 多重 pop 防止フラグ

  /// 👶 ボトムシートを安全に閉じるための関数。
  /// - 多重popやアニメーションロックを防止。
  void _safeCloseSheet(BuildContext ctx) {
    if (_pendingSheetClose) return; // すでに処理予約済み
    _pendingSheetClose = true;
    // 2 フレーム遅延: 直前の setState に伴うビルド/アニメーションロック終了を待つ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _pendingSheetClose = false;
          return;
        }
        final nav = Navigator.of(ctx);
        if (nav.canPop()) {
          try {
            nav.pop();
          } catch (e) {
            debugPrint('[SHEET][POP][WARN] $e');
          }
        }
        _pendingSheetClose = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _init(); // 👶 初期化処理（マーカー準備・避難所購読・位置取得など）
  }

  /// 👶 指定座標へ地図カメラを移動する関数。
  Future<void> moveCameraTo(LatLng latLng, {double zoom = 15}) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: zoom)));
  }

  /// 👶 他画面から特定リクエストの詳細を開くための関数。
  void focusOnRequest(DeliveryRequest r) {
    _openRequestDetail(r, fromExternal: true);
  }

  /// 👶 画面初期化処理。
  /// - マーカーアイコン準備、避難所データ購読、配達員ID取得、現在地移動などをまとめて実行。
  Future<void> _init() async {
    debugPrint('[MAP] init start');
    await _prepareMarkerIcons();
    // 避難所ストリーム購読（open のみ）
    _shelterSub = ShelterService.getAvailableShelters().listen((data) {
      if (mounted) setState(() => _shelters = data);
    });
    // シード機能は現在無効化（実運用/安定表示のため）
    // try {
    //   await ShelterService.seedProvidedSheltersIfMissing();
    // } catch (e) {
    //   debugPrint('[SEED][WARN] shelter seed failed: $e');
    // }
    await _loadPersonId();
    debugPrint('[MAP] personId=$_personId');
    await _moveToCurrentLocation();
    if (mounted) setState(() {});
    debugPrint('[MAP] init done');
  }

  // 状態別マーカー (簡易: defaultMarkerWithHue + alpha / hue の差 + 自分担当強調色)
  /// 👶 マーカーアイコンを状態ごとに準備する関数。
  /// - 待機中は赤、担当中は青、配達中はオレンジで色分け。
  Future<void> _prepareMarkerIcons() async {
    _iconWaiting = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    // 自分担当 assigned: デフォ青より濃く表示 (hueBlue は 210° 相当 → 200° 近似で強調できないため同色 + later outline は未実装)
    // 他人担当 assigned: 薄青 (標準 blue)
    _iconAssignedOthers = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    _iconDelivering = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  @override
  void dispose() {
    _shelterSub?.cancel(); // 👶 ストリーム購読解除（メモリリーク防止）
    super.dispose();
  }

  /// 👶 ローカルストレージから配達員IDを取得する関数。
  Future<void> _loadPersonId() async {
    final prefs = await SharedPreferences.getInstance();
    _personId = prefs.getString('delivery_person_id') ?? '';
  }

  /// 👶 現在地へ地図カメラを移動する関数。
  /// - 位置情報取得にタイムアウト処理も追加。
  Future<void> _moveToCurrentLocation() async {
    try {
      debugPrint('[LOC] requesting current location');
      final pos = await LocationService.getCurrentLocation().timeout(const Duration(seconds: 6), onTimeout: () {
        debugPrint('[LOC][TIMEOUT] fallback to default center');
        return null;
      });
      if (pos != null && _mapController != null) {
        debugPrint('[LOC] got position lat=${pos.latitude} lng=${pos.longitude}');
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 14),
          ),
        );
      }
    } catch (e) {
      debugPrint('[LOC][ERROR] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👶 メイン画面のUI構築。地図とFAB（表示モード切替）を配置。
    return Scaffold(
      // AppBar は MainScreen のオーバーレイ共通バーに移行
      body: _buildMapWithRequests(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _currentView = _currentView == 'emergency' ? 'all' : 'emergency'),
        backgroundColor: _currentView == 'emergency' ? Colors.red : Colors.orange,
        child: Icon(_currentView == 'emergency' ? Icons.warning : Icons.warning_outlined, color: Colors.white),
      ),
    );
  }

  // ログアウト機能は MainScreen 側に集約

  /// 👶 配達リクエストのストリームを監視し、地図上にマーカーを表示するUI構築関数。
  /// - 緊急/通常モードで表示内容を切替。
  /// - 自分担当のリクエストも別ストリームで取得し、重複なく統合。
  Widget _buildMapWithRequests() {
    final Stream<List<DeliveryRequest>> waitingStream = _currentView == 'emergency'
        ? FirebaseService.getEmergencyRequests()
        : FirebaseService.getWaitingRequests();

    // まず waiting / emergency を取得し、その後 自分担当中(active) をネストしてマージ
    return StreamBuilder<List<DeliveryRequest>>(
      stream: waitingStream,
      builder: (context, waitingSnap) {
        if (waitingSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (waitingSnap.hasError) {
          debugPrint('[MAP][ERROR] waiting: ${waitingSnap.error}');
          return Center(child: Text('❌ ${waitingSnap.error}'));
        }
        final waiting = waitingSnap.data ?? [];

        // personId 未取得なら waiting のみ表示
        if (_personId.isEmpty) {
          return _buildMapStack(waiting, const []);
        }
        return StreamBuilder<List<DeliveryRequest>>(
          stream: FirebaseService.getMyDeliveries(_personId),
          builder: (context, mySnap) {
            if (mySnap.hasError) {
              debugPrint('[MAP][ERROR] my: ${mySnap.error}');
            }
            final mine = mySnap.data ?? [];
            return _buildMapStack(waiting, mine);
          },
        );
      },
    );
  }

  Widget _buildMapStack(List<DeliveryRequest> waiting, List<DeliveryRequest> mine) {
    // mine と waiting を統合（重複なし）
    final merged = <DeliveryRequest>[]..addAll(waiting);
    final wIds = waiting.map((e) => e.id).toSet();
    for (final m in mine) { if (!wIds.contains(m.id)) merged.add(m); }

    // ==== 単一マーカー方針 ====
    // 1) shelterId があるものは shelterId ごとにグルーピング
    // 2) shelterId が無いものは 以前通り座標キーでグルーピング (完全一致)
    // 3) 各グループの代表: 緊急(high) > delivering > assigned > waiting の優先度 / 状態簡易順位で選択
    final Map<String, List<DeliveryRequest>> groups = {};
    for (final r in merged) {
      if (r.status == RequestStatus.completed) continue; // 完了はマップ非表示
      final key = r.shelterId != null && r.shelterId!.isNotEmpty
          ? 'S:${r.shelterId}'
          : 'L:${r.location.latitude.toStringAsFixed(6)}_${r.location.longitude.toStringAsFixed(6)}';
      groups.putIfAbsent(key, () => []).add(r);
    }

    int _stateRank(DeliveryRequest r) {
      if (r.priority == RequestPriority.high) return 0; // 最優先
      if (r.status == RequestStatus.delivering) return 1;
      if (r.status == RequestStatus.assigned) return 2;
      return 3; // waiting
    }

    final Set<Marker> markers = {};
    for (final entry in groups.entries) {
      final list = entry.value;
      list.sort((a,b) => _stateRank(a).compareTo(_stateRank(b))); // 代表要素先頭
      final representative = list.first;
      markers.add(_markerForGroup(representative, list));
    }

    final map = GoogleMap(
      onMapCreated: (c) {
        _mapController = c;
        debugPrint('[MAP] map created');
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: const CameraPosition(
        target: LatLng(35.681236, 139.767125),
        zoom: 12,
      ),
      mapToolbarEnabled: false, // 右下の経路/Googleマップショートカットを無効化
      markers: markers,
      circles: _currentView == 'emergency'
          ? {}
          : waiting.where((r) => r.priority == RequestPriority.high).map((r) => Circle(
                circleId: CircleId('em_${r.id}'),
                center: LatLng(r.location.latitude, r.location.longitude),
                radius: 120, // メートル
                // ignore: deprecated_member_use
                strokeColor: Colors.redAccent.withOpacity(0.55), // 警告を抑制
                strokeWidth: 1,
                // ignore: deprecated_member_use
                fillColor: Colors.redAccent.withOpacity(0.18), // 警告を抑制
              )).toSet(),
    );

    final waitingCount = waiting.length;
    final assignedCount = mine.where((e) => e.status == RequestStatus.assigned).length;
    final deliveringCount = mine.where((e) => e.status == RequestStatus.delivering).length;

    return Stack(
      children: [
        map,
        // 緊急バッジ
        Positioned(
          top: 8,
          left: 8,
          child: StreamBuilder<List<DeliveryRequest>>(
            stream: FirebaseService.getEmergencyRequests(),
            builder: (context, es) {
              final cnt = es.data?.length ?? 0;
              if (cnt == 0) return const SizedBox.shrink();
              return _badge('🆘 緊急: $cnt件', Colors.red.shade700);
            },
          ),
        ),
        // ステータスバー (中央上)
        Positioned(
          top: 8,
          right: 8,
          child: _statusBar(waitingCount, assignedCount, deliveringCount),
        ),
      ],
    );
  }

  Widget _statusBar(int waiting, int assigned, int delivering) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _countChip('待機', waiting, Colors.redAccent),
            const SizedBox(width: 6),
            _countChip('担当', assigned, Colors.blueAccent),
            const SizedBox(width: 6),
            _countChip('配達中', delivering, Colors.orangeAccent),
          ],
        ),
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label:$count'),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // 旧: リクエストごとマーカー -> 新: グループ代表マーカー
  Marker _markerForGroup(DeliveryRequest representative, List<DeliveryRequest> group) {
    // 要件: waiting が1件でもあれば赤。それ以外で "全件 delivering" ならオレンジ。それでもなければ(= assigned を最低1件含む) 青。
    // completed は除外対象なので考えられない（呼び出し元でフィルタされている想定）。
  bool hasWaiting = false;
  bool allDelivering = true; // 全件 delivering であることを仮定し、違反があれば false
    for (final r in group) {
      final st = r.status;
      if (st == RequestStatus.waiting) {
        hasWaiting = true;
        break; // 最優先決定
      }
      if (st != RequestStatus.delivering) {
        allDelivering = false; // assigned を含む
      }
      // assigned は allDelivering=false 判定で既に識別できるので個別フラグ不要
    }
    BitmapDescriptor icon;
    if (hasWaiting) {
      icon = _iconWaiting ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else if (allDelivering && group.isNotEmpty) {
      icon = _iconDelivering ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } else {
      // assigned を含む (あるいは混在: assigned + delivering)
      icon = _iconAssignedOthers ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
    final pos = LatLng(representative.location.latitude, representative.location.longitude);
    final multiple = group.length > 1;
    return Marker(
      markerId: MarkerId('grp_${representative.id}_${group.length}'),
      position: pos,
      infoWindow: const InfoWindow(),
      onTap: () {
        if (multiple) {
          _openGroupedRequestsSheet(group, anchor: pos);
        } else {
          _openRequestDetail(representative);
        }
      },
      icon: icon,
    );
  }

  void _openGroupedRequestsSheet(List<DeliveryRequest> group, {LatLng? anchor}) {
    group.sort((a,b) => a.priority.compareTo(b.priority));
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.house_siding),
                    const SizedBox(width: 8),
                    Expanded(child: Text('この地点の要請 (${group.length}件)', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: group.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = group[i];
                      return ListTile(
                        title: Text(r.item),
                        subtitle: Text('優先度: ${r.priority} / 状態: ${r.statusIcon}'),
                        leading: Text(r.priorityColor),
                        onTap: () {
                          Navigator.pop(context);
                          _openRequestDetail(r);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('閉じる'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openRequestDetail(DeliveryRequest r, {bool fromExternal = false}) async {
    if (_openingSheet) return; // 連打防止
    _openingSheet = true;

    try {
      // 位置が十分近い & ズームが既に高いならカメラアニメ省略
      final target = LatLng(r.location.latitude, r.location.longitude);
      bool needMove = true;
      if (_mapController != null) {
        final cameraPos = await _mapController!.getVisibleRegion();
        // 大雑把に対象が現在表示境界の内側なら移動省略
        if (target.latitude >= cameraPos.southwest.latitude &&
            target.latitude <= cameraPos.northeast.latitude &&
            target.longitude >= cameraPos.southwest.longitude &&
            target.longitude <= cameraPos.northeast.longitude) {
          needMove = false;
        }
      }

      if (needMove) {
        // 先に軽いハプティックで反応フィードバック
        // ignore: use_build_context_synchronously
        // HapticFeedback は platform channel を使うため import services が必要だが最小対応として try-catch で包む
        try { /* placeholder for future: HapticFeedback.lightImpact(); */ } catch (_) {}
        await moveCameraTo(target, zoom: 17);
      }

      if (!mounted) return;
      _showDetail(r);
    } finally {
      // 少し遅延してから解除 (シートアニメーション中の再タップ抑制)
      Future.delayed(const Duration(milliseconds: 300), () {
        _openingSheet = false;
      });
    }
  }

  Shelter? _findShelterForRequest(DeliveryRequest r) {
    if (_shelters.isEmpty) return null;
    // 1. shelterId 直接一致
    if (r.shelterId != null) {
      try {
        return _shelters.firstWhere((e) => e.id == r.shelterId);
      } catch (_) {}
    }
    // 2. 位置完全一致
    try {
      final exact = _shelters.firstWhere(
        (e) => e.location.latitude == r.location.latitude && e.location.longitude == r.location.longitude,
      );
      return exact;
    } catch (_) {}
    // 3. 近接一致（~20m 以内）
    const threshold = 0.0002; // 約 20m 目安
    for (final s in _shelters) {
      final dLat = (s.location.latitude - r.location.latitude).abs();
      final dLng = (s.location.longitude - r.location.longitude).abs();
      if (dLat < threshold && dLng < threshold) return s;
    }
    return null;
  }

  void _showDetail(DeliveryRequest r) {
    showModalBottomSheet(
      context: context,
      builder: (c) {
        final shelter = _findShelterForRequest(r);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.priorityColor, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.item, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Text(r.statusIcon, style: const TextStyle(fontSize: 24)),
                ],
              ),
              const SizedBox(height: 12),
              Text('状態: ${r.status}'),
              if (shelter != null) Text('避難所: ${shelter.name}'),
              Text('要請者: ${(r.requesterName.isEmpty ? null : r.requesterName) ?? '匿名さん'}'),
              if (r.phone != null) Text('連絡先: ${r.phone}'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text('経路案内'),
                  onPressed: () => _launchExternalNav(r.location.latitude, r.location.longitude, label: shelter?.name ?? r.item),
                ),
              ),
              const SizedBox(height: 8),
              // 競合 UI 制御判定
              if (((r.status == RequestStatus.assigned) || (r.status == RequestStatus.delivering)) && !(r.deliveryPersonId == _personId && _personId.isNotEmpty))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Text(
                    '🚫 他の配達員が対応中です',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                )
              else if (r.status == RequestStatus.waiting)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.handshake),
                    label: const Text('🤝 この配達を引き受ける'),
                    onPressed: (_personId.isEmpty || _sheetActionRunning) ? null : () async {
                      if (_sheetActionRunning) return; // 二重防止
                      setState(() => _sheetActionRunning = true);
                      final rootContext = this.context; // Snackbar 用にシート外コンテキスト確保
                      try {
                        final ok = await FirebaseService.assignDelivery(r.id, _personId);
                        if (!mounted) return;
                        if (ok) {
                          _safeCloseSheet(context);
                        } else {
                          ScaffoldMessenger.of(rootContext)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(const SnackBar(
                              content: Text('他の配達員が先に取得しました'),
                              duration: Duration(seconds: 2),
                            ));
                        }
                      } finally {
                        if (mounted) setState(() => _sheetActionRunning = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                )
              else if (r.status == RequestStatus.assigned && r.deliveryPersonId == _personId)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.rocket_launch),
                        label: const Text('🚀 配達開始'),
                        onPressed: _sheetActionRunning ? null : () async {
                          if (_sheetActionRunning) return;
                          setState(() => _sheetActionRunning = true);
                          final rootContext = this.context;
                          try {
                            final _ = await FirebaseService.startDelivery(r.id, _personId);
                            if (!mounted) return;
                            _safeCloseSheet(context);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(content: Text('失敗: $e')));
                            }
                          } finally {
                            if (mounted) setState(() => _sheetActionRunning = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.undo),
                        label: const Text('引き受け解除'),
                        onPressed: _sheetActionRunning ? null : () async {
                          if (_sheetActionRunning) return;
                          setState(() => _sheetActionRunning = true);
                          final rootContext = this.context;
                          try {
                            await FirebaseService.cancelAssignment(r.id, _personId);
                            if (mounted) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(const SnackBar(content: Text('引き受けを解除しました')));
                            }
                            if (mounted) _safeCloseSheet(context);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(content: Text('失敗: $e')));
                            }
                          } finally {
                            if (mounted) setState(() => _sheetActionRunning = false);
                          }
                        },
                      ),
                    ),
                  ],
                )
              else if (r.status == RequestStatus.delivering)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('✅ 配達完了'),
                    onPressed: _sheetActionRunning ? null : () async {
                      if (_sheetActionRunning) return;
                      setState(() => _sheetActionRunning = true);
                      final rootContext = this.context;
                      try {
                        await FirebaseService.completeDelivery(r.id);
                        if (mounted) _safeCloseSheet(context);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(content: Text('失敗: $e')));
                        }
                      } finally {
                        if (mounted) setState(() => _sheetActionRunning = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
              // 管理者のみ: completed -> waiting 再利用ボタン (現状 completed はマップに出さないが将来表示に備え簡素に追加)
              if (r.status == RequestStatus.completed)
                FutureBuilder<String?>(
                  future: SharedPreferences.getInstance().then((p) => p.getString('delivery_person_id')),
                  builder: (context, snap) {
                    final uid = snap.data;
                    final isAdmin = uid != null && AdminConfig.adminUids.contains(uid);
                    if (!isAdmin) return const SizedBox.shrink();
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('♻️ 再利用 (waitingへ)'),
                        onPressed: _sheetActionRunning ? null : () async {
                          if (_sheetActionRunning) return;
                          setState(() => _sheetActionRunning = true);
                          final rootContext = this.context;
                          try {
                            final ok = await FirebaseService.reopenRequest(r.id, uid);
                            if (!mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(const SnackBar(content: Text('再利用しました')));
                              _safeCloseSheet(context);
                            } else {
                              ScaffoldMessenger.of(rootContext).showSnackBar(const SnackBar(content: Text('再利用失敗 (状態競合)')));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(content: Text('失敗: $e')));
                            }
                          } finally {
                            if (mounted) setState(() => _sheetActionRunning = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchExternalNav(double lat, double lng, {String? label}) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving&destination_place_id=&destination_name=${Uri.encodeComponent(label ?? '目的地')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('地図アプリを開けませんでした')));
    }
  }
}