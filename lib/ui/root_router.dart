// lib/ui/root_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 既存画面（プロジェクト内の実ファイル名に合わせて import）
import '../login_screen.dart';                // 配達員ログイン（既存）
import '../main_screen.dart';                 // 配達員メイン（既存）
import '../delivery_map_screen.dart';         // マップ（既存）
import '../delivery_progress_screen.dart';    // 進行（既存）

// --- 被災者側 既存画面 ---
import './shelter_select_screen.dart';        // 避難所選択（ui 配下）
import '../shelter_list_screen.dart';         // 避難所一覧（lib 直下）
import './request_create_screen.dart';        // 依頼作成（ui 配下）
import './order_status_screen.dart';          // 依頼ステータス（ui 配下）

// --- オプション ---
import '../license_screen.dart';
import '../profile_setup_screen.dart';
import '../profile_edit_screen.dart';

/// 外部から呼ぶファクトリ
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/role',
    routes: [
      // 0) レガシー別名（Navigator.pushNamed('/profile_setup') が残っていても落ちないよう保険）
      GoRoute(
        path: '/profile_setup',
        redirect: (_, __) => '/profile/setup',
      ),

      // 1) ロール選択ランディング（被災者/配達員タブ）
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleGateScreen(),
      ),

      // 2) 被災者側ルート
      ShellRoute(
        builder: (context, state, child) => UserShell(child: child),
        routes: [
          GoRoute(
            path: '/user/home',
            builder: (context, state) => const ShelterSelectScreen(),
          ),
          GoRoute(
            path: '/user/shelters',
            builder: (context, state) => const ShelterListScreen(),
          ),
          GoRoute(
            path: '/user/request',
            builder: (context, state) => const RequestCreateScreen(),
          ),
          GoRoute(
            path: '/user/status',
            builder: (context, state) => const OrderStatusScreen(),
          ),
          GoRoute(
            path: '/user/map',
            builder: (context, state) => const DeliveryMapScreen(),
          ),
        ],
      ),

      // 3) 配達員側ルート（既存のログイン→メイン）
      GoRoute(
        path: '/courier/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/courier/main',
        builder: (context, state) => const MainScreen(),
      ),
      // progress は /courier/progress/:deliveryPersonId 必須
      GoRoute(
        path: '/courier/progress/:deliveryPersonId',
        builder: (context, state) => DeliveryProgressScreen(
          deliveryPersonId: state.pathParameters['deliveryPersonId']!,
        ),
      ),

      // 共通
      GoRoute(path: '/license', builder: (c, s) => const LicenseScreen()),
      GoRoute(path: '/profile/setup', builder: (c, s) => const ProfileSetupScreen()),
      GoRoute(path: '/profile/edit', builder: (c, s) => const ProfileEditScreen()),
    ],

    // 認可リダイレクト（最低限）
    redirect: (context, state) {
      // 配達員メイン/進行はログイン必須
      final isCourierMain = state.matchedLocation == '/courier/main';
      final isCourierProgress = state.matchedLocation.startsWith('/courier/progress');
      if (isCourierMain || isCourierProgress) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return '/courier/login';
      }
      return null;
    },
  );
}

/// ロール選択のランディング（タブで切替）
class RoleGateScreen extends StatefulWidget {
  const RoleGateScreen({super.key});

  @override
  State<RoleGateScreen> createState() => _RoleGateScreenState();
}

class _RoleGateScreenState extends State<RoleGateScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Delivery'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.person_pin_circle), text: '被災者として使う'),
            Tab(icon: Icon(Icons.delivery_dining), text: '配達員として使う'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _VictimLanding(),
          _CourierLanding(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '※ 同じアプリ内でロールを切替できます',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.outline),
          ),
        ),
      ),
    );
  }
}

/// 被災者ランディング：最寄り避難所へ誘導＋依頼作成/状況確認
class _VictimLanding extends StatelessWidget {
  const _VictimLanding();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _CardTitle('被災者向け'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.go('/user/home'),
          icon: const Icon(Icons.house_rounded),
          label: const Text('避難所を登録/選択する'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.go('/user/request'),
          icon: const Icon(Icons.add_box),
          label: const Text('物資を依頼する'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/user/status'),
          icon: const Icon(Icons.timeline),
          label: const Text('依頼の進捗を見る'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.go('/user/map'),
          icon: const Icon(Icons.map),
          label: const Text('地図で避難所/拠点を確認'),
        ),
      ],
    );
  }
}

/// 配達員ランディング：既存のログイン→メインへ
class _CourierLanding extends StatelessWidget {
  const _CourierLanding();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _CardTitle('配達員向け'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.go('/courier/login'),
          icon: const Icon(Icons.login),
          label: const Text('配達員としてログイン'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/courier/main'),
          icon: const Icon(Icons.dashboard_customize),
          label: const Text('ダッシュボードへ（ログイン済み想定）'),
        ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// 被災者側共通のシェル（必要に応じて BottomNav に差し替え可）
class UserShell extends StatelessWidget {
  const UserShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}