import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 👤 配達員プロフィール設定画面
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  File? _profileImage;
  String? _profileImageUrl;
  bool _isLoading = false;
  String _selectedVehicleType = '🚗 自動車';

  final List<String> _vehicleTypes = [
    '🚗 自動車',
    '🏍️ バイク',
    '🚲 自転車',
    '🚶 徒歩',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('👤 新規配達員プロフィール設定'),
        backgroundColor: Colors.blue.shade100,
        automaticallyImplyLeading: false, // 戻るボタンを非表示
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 既存アカウントログイン CTA カード
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.indigo.shade600, Colors.blue.shade400]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.login, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('既にメール登録済みの方はこちら', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('過去にプロフィールを作成済みなら再入力不要でログインできます。', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('🔐 ログインへ進む'),
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    ),
                  ),
                ],
              ),
            ),
            // � 新規登録説明
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '🎉 配達員として新規登録します',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '災害時の配達を支援するための基本情報を入力してください。',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
            
            // �📷 プロフィール写真
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                      border: Border.all(
                        color: Colors.blue.shade300,
                        width: 3,
                      ),
                    ),
                    child: _profileImage != null
                        ? ClipOval(
                            child: Image.file(
                              _profileImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : _profileImageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  _profileImageUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 📨 アカウント永続化 (任意)
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: '📨 メールアドレス（任意）',
                hintText: 'example@domain.jp',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '🔐 パスワード（任意 / 8文字以上）',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '※ メールとパスワードを設定すると別端末でも同じ配達員として利用できます。\n'
                // 👶 注意文を赤文字で表示
                '※ 未設定のままログアウトすると再ログインできません（端末内のみ有効な匿名アカウントになります）',
                style: TextStyle(fontSize: 12, height: 1.3, color: Colors.red),
              ),
            ),
            const SizedBox(height: 20),

            // 👤 配達員名入力（必須）
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '👤 配達員名 ※必須',
                hintText: '山田 太郎',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                errorText: _nameController.text.trim().isEmpty ? '配達員名を入力してください' : null,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '配達員名を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 🚗 配送手段選択（必須）
            DropdownButtonFormField<String>(
              value: _selectedVehicleType,
              decoration: InputDecoration(
                labelText: '🚗 配送手段 ※必須',
                prefixIcon: const Icon(Icons.directions_car),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _vehicleTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedVehicleType = newValue;
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '配送手段を選択してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // 🆔 車両ナンバー/識別情報（任意）
            TextFormField(
              controller: _vehicleController,
              decoration: InputDecoration(
                labelText: '🆔 車両ナンバー・識別情報（任意）',
                hintText: '品川 500 あ 1234',
                prefixIcon: const Icon(Icons.confirmation_number),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // ℹ️ 注意事項
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '配達員としての注意事項',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 災害時の配達は安全第一で行ってください\n'
                    '• 被災者の方々への配慮を忘れずに\n'
                    '• 配達状況は適切に更新してください',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ✅ 登録完了ボタン
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '🎉 新規配達員として登録完了',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  // 📷 プロフィール画像選択（日本語ダイアログ）
  Future<void> _pickImage() async {
    try {
      // 🌸 日本語での選択ダイアログを表示
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.blue),
                SizedBox(width: 8),
                Text('📷 プロフィール写真を選択'),
              ],
            ),
            content: const Text('プロフィール写真の取得方法を選択してください'),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('📷 カメラで撮影'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('📱 ギャラリーから選択'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
            ],
          );
        },
      );

      if (source != null) {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );
        
        if (image != null) {
          setState(() {
            _profileImage = File(image.path);
          });
          _showSnackBar('✅ プロフィール写真を設定しました');
        }
      }
    } catch (e) {
      _showSnackBar('❌ 画像の選択に失敗しました: $e');
    }
  }

  // 💾 プロフィール保存
  Future<void> _saveProfile() async {
    // フォーム全体のバリデーションチェック
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('❌ 入力項目を確認してください');
      return;
    }

    // 必須項目のバリデーション
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('❌ 配達員名を入力してください');
      return;
    }

    if (_selectedVehicleType.isEmpty) {
      _showSnackBar('❌ 配送手段を選択してください');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('[PROFILE] save start');
      var user = _auth.currentUser;
      if (user == null) {
        // main.dartで匿名認証実施済み想定。ここに来た場合は再試行。
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
      }

      String? imageUrl;
      
      // 📷 プロフィール画像をアップロード
      if (_profileImage != null) {
        final currentUid = user?.uid ?? FirebaseAuth.instance.currentUser!.uid;
        // Storage ルール match /profile_images/{userId} に合わせて拡張子を付けずに保存
        final ref = _storage.ref().child('profile_images/$currentUid');
        try {
          await ref.putFile(_profileImage!);
          imageUrl = await ref.getDownloadURL();
          debugPrint('[PROFILE][IMAGE] uploaded');
        } catch (e) {
          debugPrint('[PROFILE][IMAGE][WARN] upload skipped: $e');
          // 画像失敗は致命ではないので続行
        }
      }

      // メール/パスワード任意リンク
      final email = _emailController.text.trim();
      final pass = _passwordController.text.trim();
      if (email.isNotEmpty || pass.isNotEmpty) {
        if (email.isEmpty || pass.length < 8) {
          _showSnackBar('❌ メールは必須・パスワードは8文字以上で入力');
          setState(() => _isLoading = false);
          return;
        }
        try {
          final cred = EmailAuthProvider.credential(email: email, password: pass);
          await user!.linkWithCredential(cred);
          debugPrint('[PROFILE][AUTH] email linked');
        } catch (e) {
          debugPrint('[PROFILE][AUTH][WARN] link failed: $e');
          _showSnackBar('⚠️ メール連携失敗 (後で再設定可)');
        }
      }

      // 💾 Firestoreにプロフィール保存
      final uid = FirebaseAuth.instance.currentUser!.uid;
      debugPrint('[PROFILE] writing doc uid=$uid');
      await _firestore.collection('delivery_persons').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'vehicleType': _selectedVehicleType,
        'vehicleNumber': _vehicleController.text.trim(),
        'profileImageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (email.isNotEmpty) 'email': email,
        // rating / deliveryCount など評価系はルール必須外のため一旦省略
      });

      // 📱 ローカルにも保存
      final prefs = await SharedPreferences.getInstance();
  await prefs.setString('delivery_person_id', uid);
      await prefs.setString('delivery_person_name', _nameController.text.trim());

      // ✅ 配達マップ画面へ (context安全対策)
      if (!mounted) return; // 画面が dispose 済みなら終了
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('🎉 新規配達員として登録が完了しました！'),
          backgroundColor: Colors.blue.shade800,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return; // 待機中に外れた場合
      debugPrint('[PROFILE] navigate -> /main');
      navigator.pushReplacementNamed('/main');
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('[PROFILE][ERROR] $e');
      _showSnackBar('❌ 新規配達員登録に失敗しました: $e');
    }
  }

  // _saveTestProfile 削除（匿名認証＋単一フローに統合）

  // 📢 スナックバー表示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue.shade800,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vehicleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}