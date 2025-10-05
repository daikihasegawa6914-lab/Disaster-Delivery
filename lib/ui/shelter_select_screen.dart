import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class ShelterSelectScreen extends StatelessWidget {
  const ShelterSelectScreen({super.key});

  Future<void> _ensureAnonymousAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (_) {
        // ネット不調でも画面は進める（オフラインキューで後同期）
      }
    }
  }

  Future<void> _selectShelterAndGoNext(
    BuildContext context, {
    required String shelterId,
    required String shelterName,
  }) async {
    // 1) できれば匿名サインイン
    await _ensureAnonymousAuth();

    // 2) 端末に保存（依頼作成画面で参照）
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_shelter_id', shelterId);
    await prefs.setString('selected_shelter_name', shelterName);

    // 3) 画面遷移：被災者の依頼作成へ
    if (context.mounted) context.go('/user/request');
  }

  @override
  Widget build(BuildContext context) {
    final sheltersRef =
        FirebaseFirestore.instance.collection('shelters').orderBy('name');

    return Scaffold(
      appBar: AppBar(
        title: const Text('避難所を選択'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '戻る',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/role');
            }
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: sheltersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // オフラインや DNS 不調などでも進められる UI にする
            return _ErrorAndSkip(
              message: '避難所データの取得に失敗しました\n（オフラインでも続行できます）',
              onSkip: () => _selectShelterAndGoNext(
                context,
                shelterId: 'unknown',
                shelterName: '避難所未選択',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return _ErrorAndSkip(
              message: '避難所データが見つかりませんでした',
              onSkip: () => _selectShelterAndGoNext(
                context,
                shelterId: 'unknown',
                shelterName: '避難所未選択',
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = (data['name'] ?? '名称未設定').toString();
              final address = (data['address'] ?? '').toString();

              return ListTile(
                title: Text(name),
                subtitle: address.isNotEmpty ? Text(address) : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectShelterAndGoNext(
                  context,
                  shelterId: docs[index].id,
                  shelterName: name,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorAndSkip extends StatelessWidget {
  const _ErrorAndSkip({required this.message, required this.onSkip});
  final String message;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.wifi_off, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSkip,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('避難所を選ばずに進む'),
          ),
        ],
      ),
    );
  }
}