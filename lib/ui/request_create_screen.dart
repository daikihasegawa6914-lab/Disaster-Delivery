import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequestCreateScreen extends StatefulWidget {
  const RequestCreateScreen({super.key});

  @override
  State<RequestCreateScreen> createState() => _RequestCreateScreenState();
}

class _RequestCreateScreenState extends State<RequestCreateScreen> {
  int _step = 0;

  final Map<String, int> _catalog = {
    '飲料水(2L)': 0,
    'レトルト食品': 0,
    '缶詰': 0,
    'おむつ': 0,
    '生理用品': 0,
    '毛布': 0,
    'モバイルバッテリー': 0,
  };

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _shelterId;
  String? _shelterName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedShelter();
  }

  Future<void> _loadSelectedShelter() async {
    final prefs = await SharedPreferences.getInstance();
    _shelterId = prefs.getString('selected_shelter_id');
    _shelterName = prefs.getString('selected_shelter_name');

    // 住所に避難所名を初期値として入れておく（編集可）
    if ((_addressCtrl.text.trim().isEmpty) && (_shelterName != null)) {
      _addressCtrl.text = '$_shelterName';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

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

  /// オフライン時の送信内容キュー（SharedPreferences）
  Future<void> _enqueueOffline(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'pending_request_queue';
    payload['__queuedAt'] = DateTime.now().toIso8601String();

    final raw = prefs.getString(key);
    List list;
    if (raw == null || raw.isEmpty) {
      list = [payload];
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded..add(payload);
        } else {
          list = [payload];
        }
      } catch (_) {
        list = [payload];
      }
    }
    await prefs.setString(key, jsonEncode(list));
  }

  String _computeItemName() {
    final selected = _catalog.entries.where((e) => e.value > 0).toList();
    if (selected.isEmpty) return '未選択';
    if (selected.length == 1) {
      final e = selected.first;
      return '${e.key} x${e.value}';
    }
    final total = selected.fold<int>(0, (sum, e) => sum + e.value);
    return '複数(${total}点)';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _step = 1);
      return;
    }
    if (_catalog.values.every((q) => q == 0)) {
      setState(() => _step = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('少なくとも1つの物資を選択してください')),
      );
      return;
    }

    setState(() => _submitting = true);
    await _ensureAnonymousAuth();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    final items = _catalog.entries
        .where((e) => e.value > 0)
        .map((e) => {'name': e.key, 'quantity': e.value})
        .toList();

    // オンライン・オフライン共通のデータ
    final basePayload = <String, dynamic>{
      'uid': uid,
      'itemName': _computeItemName(),
      'items': items,
      'contact': {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      },
      'userName': _nameCtrl.text.trim(),
      'shelterId': _shelterId,
      'shelterName': _shelterName,
      'priority': 'high',
      'status': 'waiting',
      'deliveryPersonId': null,
      'location': {'lat': 35.685573, 'lng': 139.739317},
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      // --- Ensure auth & log ---
      var currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        try {
          await FirebaseAuth.instance.signInAnonymously();
          currentUser = FirebaseAuth.instance.currentUser;
        } catch (_) {}
      }
      final uidNowForCreate = currentUser?.uid;
      debugPrint('[REQUEST] create start uid=$uidNowForCreate');

      // --- Normalize phone to match Security Rules regex ^[0-9+\-]{10,15}$ ---
      final phoneSanitized = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9+\-]'), '');

      final now = FieldValue.serverTimestamp();
      final itemName = _computeItemName();

      final docRef = await FirebaseFirestore.instance
          .collection('requests')
          .add({
        'uid': uid,
        'itemName': itemName, // 例: "医薬品セット" や "複数(n点)"
        'items': items,
        'contact': {
          'name': _nameCtrl.text.trim(),
          'phone': phoneSanitized,
          'address': _addressCtrl.text.trim(),
          'notes': _notesCtrl.text.trim(),
        },
        'userName': _nameCtrl.text.trim(), // 被災者氏名（任意の冗長フィールド）
        'shelterId': _shelterId,
        'shelterName': _shelterName,
        'priority': 'high',
        'status': 'waiting',
        'deliveryPersonId': null,
        'location': GeoPoint(35.685573, 139.739317),
        'createdAt': now,
        'updatedAt': now,
      });
      // 連絡先を端末/サーバに保存（任意）
      final uidNow = FirebaseAuth.instance.currentUser?.uid;
      if (uidNow != null) {
        await FirebaseFirestore.instance
            .collection('app_users')
            .doc(uidNow)
            .set({
          'uid': uidNow,
          'role': 'victim',
          'name': _nameCtrl.text.trim(),
          'phone': phoneSanitized,
          'address': _addressCtrl.text.trim(),
          'updated_at': now,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('依頼を送信しました（ID: ${docRef.id}）')),
      );
      context.go('/user/status');
    } on FirebaseException catch (e) {
      debugPrint('[REQUEST][ERROR] code=${e.code} message=${e.message}');
      // ルール違反（permission-denied）や接続断のどちらでもオフラインキューへ退避
      await _enqueueOffline(Map<String, dynamic>.from(basePayload));

      if (!mounted) return;
      final msg = (e.code == 'permission-denied')
          ? '送信が拒否されました。入力の電話番号や必須項目を確認してください。'
          : 'ネットワーク未接続のため端末に保存しました。復帰後に自動送信します。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      context.go('/user/status');
    } catch (e) {
      debugPrint('[REQUEST][ERROR][unknown] $e');
      await _enqueueOffline(Map<String, dynamic>.from(basePayload));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('送信に失敗しました。後で自動再送します。')),
      );
      context.go('/user/status');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shelterInfo = (_shelterName == null)
        ? const Text('避難所が未選択です。戻って選択してください。')
        : Text('選択中の避難所: $_shelterName');

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/user/home');
            }
          },
        ),
        title: const Text('物資依頼'),
      ),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (_step == 0) {
            setState(() => _step = 1);
          } else {
            _submit();
          }
        },
        onStepCancel: () {
          if (_step == 1) setState(() => _step = 0);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _submitting ? null : details.onStepContinue,
                  child: Text(_step == 0 ? '次へ' : '送信'),
                ),
                const SizedBox(width: 8),
                if (_step == 1)
                  TextButton(
                    onPressed: _submitting ? null : details.onStepCancel,
                    child: const Text('戻る'),
                  ),
                if (_submitting) ...[
                  const SizedBox(width: 16),
                  const Expanded(child: LinearProgressIndicator()),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('物資を選ぶ'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shelterInfo,
                const SizedBox(height: 8),
                _buildCatalog(),
              ],
            ),
          ),
          Step(
            title: const Text('連絡先・個人情報'),
            isActive: _step >= 1,
            state: StepState.indexed,
            content: _buildContactForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog() {
    return Column(
      children: _catalog.keys.map((k) {
        final qty = _catalog[k] ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(k)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      final v = (_catalog[k] ?? 0);
                      if (v > 0) _catalog[k] = v - 1;
                    });
                  },
                ),
                Text('$qty'),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    setState(() {
                      final v = (_catalog[k] ?? 0) + 1;
                      _catalog[k] = v;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContactForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'お名前',
              prefixIcon: Icon(Icons.person),
              filled: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: '電話番号',
              prefixIcon: Icon(Icons.phone),
              filled: true,
            ),
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'お届け先(避難所名/場所など)',
              prefixIcon: Icon(Icons.location_on),
              filled: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: '備考(任意)',
              prefixIcon: Icon(Icons.notes),
              filled: true,
            ),
            minLines: 1,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}