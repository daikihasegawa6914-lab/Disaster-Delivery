import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ShelterSelectScreen extends StatelessWidget {
  const ShelterSelectScreen({super.key});

  Future<void> _saveShelter(BuildContext context, String shelterId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('app_users').doc(uid).set({
        'uid': uid,
        'role': 'victim',
        'shelter_id': shelterId,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('避難所を登録しました')),
        );
        Navigator.of(context).pop(); // 必要なら依頼作成画面に遷移に変更
        // Navigator.of(context).pushReplacementNamed('/request/create');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheltersRef = FirebaseFirestore.instance
        .collection('shelters')
        .orderBy('name');

    return Scaffold(
      appBar: AppBar(title: const Text('避難所を選択')),
      body: StreamBuilder<QuerySnapshot>(
        stream: sheltersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('読み込みエラー: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('避難所データがありません'));
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
                onTap: () => _saveShelter(context, docs[index].id),
              );
            },
          );
        },
      ),
    );
  }
}