import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

// 🔐 既存ユーザーログイン画面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim().toLowerCase();
      final pass = _passwordController.text.trim();

      // 既に匿名ユーザーがあれば signOut → 正規サインイン
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);
      final uid = cred.user!.uid;
      await FirebaseAuth.instance.setLanguageCode('ja');

      // Firestore プロフィール存在確認
      final docRef = FirebaseFirestore.instance
          .collection('delivery_persons')
          .doc(uid);
      final snap = await docRef.get();

      String name;
      if (!snap.exists) {
        // 過去に作られていないケース: 新規作成
        name = '未設定';
        await docRef.set({
          'uid': uid,
          'name': name,
          'vehicleType': '🚗 自動車',
          'vehicleNumber': '',
          'profileImageUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'email': email,
          'isActive': true,
        });
      } else {
        name = (snap.data()?['name'] ?? '未設定').toString();
        await docRef.update({
          'lastActiveAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 共有プリファレンスに保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('delivery_person_id', uid);
      await prefs.setString('delivery_person_name', name);

      if (!mounted) return;
      // ✅ GoRouter を使って配達員ダッシュボードへ（旧 Navigator.* を廃止）
      context.go('/courier/main');
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'ユーザーが存在しません';
          break;
        case 'wrong-password':
          msg = 'パスワードが違います';
          break;
        case 'invalid-email':
          msg = 'メール形式が不正です';
          break;
        default:
          msg = 'ログイン失敗: ${e.code}';
      }
      _showSnack(msg);
    } catch (e) {
      _showSnack('ログインエラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 既存アカウントでログイン'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                          labelText: 'メールアドレス',
                          prefixIcon: Icon(Icons.email),
                          filled: true),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      validator: (v) {
                        if (v == null || v.isEmpty) return '必須';
                        final ok = RegExp(r'^.+@.+\..+$').hasMatch(v);
                        return ok ? null : 'メール形式が不正です';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                          labelText: 'パスワード',
                          prefixIcon: Icon(Icons.lock),
                          filled: true),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _loading ? null : _login(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? '必須'
                          : (v.length < 6 ? '6文字以上を入力' : null),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: const Icon(Icons.login),
                        label: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('ログイン'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      // ✅ GoRouter に合わせてアンダースコア→スラッシュ表記へ
                      onPressed: _loading ? null : () => context.go('/profile/setup'),
                      child: const Text('新規登録へ戻る'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}