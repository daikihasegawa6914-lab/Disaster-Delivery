import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 👶 このファイルは「配達員プロフィール編集画面」のロジックです。
// - Firebase Firestoreを使ってプロフィール情報を保存・更新します。
// - 名前や配送手段などの入力フォームがあり、バリデーションも行います。
// - 編集完了時はSnackBarで通知し、画面遷移も制御します。
// - 画面の状態管理はsetStateで行い、非同期処理も安全に実装されています。
// - 既存のプロフィール情報は初期値としてフォームに反映されます。
// - 変更内容はFirestoreとローカル（SharedPreferences）両方に保存されます。
// - 画面のUIはMaterial Designをベースにしています。

// 👤 プロフィール編集画面（既存配達員向け）
// 初回登録時の ProfileSetupScreen と異なり：
//  - 既存データのロード
//  - メール未設定 → 追加リンク可
//  - メール設定済 → 変更(updateEmail) / パスワード再設定(updatePassword) 可
//  - Firestore ルールに合わせ updatedAt 必須で更新
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  // 👶 Firebase関連のインスタンスを用意
  final _auth = FirebaseAuth.instance; // 認証
  final _firestore = FirebaseFirestore.instance; // データベース
  final _storage = FirebaseStorage.instance; // 画像保存
  final _picker = ImagePicker(); // 画像選択
  final _formKey = GlobalKey<FormState>(); // フォームバリデーション

  // 👶 入力フォーム用コントローラー
  final _nameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String _vehicleType = '🚗 自動車'; // 初期値
  File? _newImageFile; // 新しい画像ファイル
  String? _currentImageUrl; // 現在の画像URL
  bool _loading = true; // 読み込み中フラグ
  bool _saving = false; // 保存中フラグ
  bool _hasEmail = false; // 既にメールリンク済みか

  // 👶 配送手段の選択肢
  final List<String> _vehicleTypes = const [
    '🚗 自動車',
    '🏍️ バイク',
    '🚲 自転車',
    '🚶 徒歩',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile(); // 👶 画面表示時にプロフィール情報を取得
  }

  Future<void> _loadProfile() async {
    // 👶 Firestoreから既存プロフィール情報を取得し、フォームに反映
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }
      final doc = await _firestore.collection('delivery_persons').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _nameController.text = (data['name'] ?? '').toString();
        _vehicleType = (data['vehicleType'] ?? _vehicleType).toString();
        _vehicleNumberController.text = (data['vehicleNumber'] ?? '').toString();
        _currentImageUrl = data['profileImageUrl'] as String?;
        if (data['email'] != null && (data['email'] as String).isNotEmpty) {
          _emailController.text = data['email'];
          _hasEmail = true;
        }
      }
    } catch (e) {
      debugPrint('[PROFILE_EDIT][ERROR] load failed: $e');
      if (mounted) _showSnack('❌ プロフィール読み込み失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    // 👶 画像選択ダイアログを表示し、選択された画像をセット
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('📷 プロフィール写真を選択'),
          content: const Text('取得方法を選択してください'),
          actions: [
            TextButton.icon(onPressed: () => Navigator.pop(c, ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('カメラ')), 
            TextButton.icon(onPressed: () => Navigator.pop(c, ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('ギャラリー')), 
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('キャンセル')),
          ],
        ),
      );
      if (source == null) return;
      final picked = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (picked != null) {
        setState(() => _newImageFile = File(picked.path));
        _showSnack('✅ 画像を選択しました');
      }
    } catch (e) {
      _showSnack('❌ 画像選択に失敗: $e');
    }
  }

  Future<void> _save() async {
    // 👶 入力内容をバリデーションし、Firestoreとローカルに保存
    if (!_formKey.currentState!.validate()) return;
    if (_nameController.text.trim().isEmpty) {
      _showSnack('❌ 配達員名は必須です');
      return;
    }
    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnack('❌ 認証状態が無効です (再起動してください)');
        return;
      }

      String? imageUrl = _currentImageUrl;
      if (_newImageFile != null) {
        try {
          final ref = _storage.ref().child('profile_images/${user.uid}');
            await ref.putFile(_newImageFile!);
            imageUrl = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('[PROFILE_EDIT][WARN] image upload failed: $e');
          _showSnack('⚠️ 画像アップロード失敗 (後で再試行)');
        }
      }

      final newEmail = _emailController.text.trim();
      final newPass = _newPasswordController.text.trim();

      // 👶 メール/パスワード関連処理
      if (!_hasEmail && newEmail.isNotEmpty && newPass.isNotEmpty) {
        // 未リンク → linkWithCredential
        if (newPass.length < 8) {
          _showSnack('❌ パスワードは8文字以上');
        } else {
          try {
            await user.linkWithCredential(EmailAuthProvider.credential(email: newEmail, password: newPass));
            _hasEmail = true;
            _showSnack('✅ メールをリンクしました');
          } catch (e) {
            _showSnack('⚠️ メールリンク失敗: $e');
          }
        }
      } else if (_hasEmail) {
        // 既にメールあり → 変更 / パス更新
        if (newEmail.isNotEmpty && newEmail != user.email) {
          try {
            await user.verifyBeforeUpdateEmail(newEmail); // 👶 メール変更は新APIで安全に
            _showSnack('✅ メールを更新しました');
          } catch (e) {
            _showSnack('⚠️ メール更新失敗: $e');
          }
        }
        if (newPass.isNotEmpty) {
          if (newPass.length < 8) {
            _showSnack('❌ 新パスワードは8文字以上');
          } else {
            try {
              await user.updatePassword(newPass);
              _showSnack('✅ パスワードを更新しました');
            } catch (e) {
              _showSnack('⚠️ パスワード更新失敗: $e');
            }
          }
        }
      }

      // 👶 Firestore 更新処理
      await _firestore.collection('delivery_persons').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'vehicleType': _vehicleType,
        'vehicleNumber': _vehicleNumberController.text.trim(),
        'profileImageUrl': imageUrl,
        if (newEmail.isNotEmpty) 'email': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });

      // 👶 ローカルキャッシュも更新
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('delivery_person_name', _nameController.text.trim());

      if (!mounted) return;
      _showSnack('💾 保存しました');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('❌ 保存失敗: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    // 👶 画面下部にメッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    // 👶 コントローラーのメモリ解放
    _nameController.dispose();
    _vehicleNumberController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // 👶 読み込み中はローディング表示
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ プロフィール編集'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                        border: Border.all(color: Colors.blue.shade300, width: 3),
                      ),
                      child: _newImageFile != null
                          ? ClipOval(child: Image.file(_newImageFile!, fit: BoxFit.cover))
                          : _currentImageUrl != null
                              ? ClipOval(child: Image.network(_currentImageUrl!, fit: BoxFit.cover))
                              : Icon(Icons.person, size: 60, color: Colors.grey.shade400),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: IconButton(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '👤 配達員名 *', filled: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _vehicleType,
                items: _vehicleTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _vehicleType = v ?? _vehicleType),
                decoration: const InputDecoration(labelText: '🚗 配送手段 *', filled: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(labelText: '🆔 車両ナンバー (任意)', filled: true),
              ),
              const SizedBox(height: 32),
              Text('🔐 アカウント (メール/パスワード) 再設定', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _hasEmail ? '📨 登録メール (変更可)' : '📨 メール (未設定 → 追加)',
                  filled: true,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _hasEmail ? '🔐 新パスワード (変更時)' : '🔐 パスワード (リンク用 8文字以上)',
                  filled: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _hasEmail
                    ? '※ メールを変更すると再認証が必要になる場合があります (失敗時はログアウト→再ログインで再試行)。'
                    : '※ まだメール未設定です。メール + パスワードを入力すると本アカウントを端末間で共有できます。',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('💾 変更を保存'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context, false),
                  child: const Text('キャンセル'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
