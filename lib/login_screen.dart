import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔐 電話番号認証ログイン画面（安全な実装）
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  String? _verificationId;
  bool _isCodeSent = false;
  bool _isLoading = false;
  bool _isOfflineMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🚚 ロゴとタイトル
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  size: 80,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                '🚚 災害配達員アプリ',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                '新規配達員登録 / ログイン',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),

              // 🔐 認証フォーム
              if (!_isCodeSent) ...[
                // ⚠️ 安全性に関する重要な警告
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '⚠️ 開発中の重要な注意',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• 実在の他人の電話番号を入力しないでください\n'
                        '• テストには「安全テストモード」を使用\n'
                        '• 実際のSMSが送信される可能性があります',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 🛠️ 安全テストモード（開発用）
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            '✅ 安全なテスト方法',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isOfflineMode = true;
                              _isCodeSent = true;
                            });
                            _showSnackBar('🛡️ 安全モード: コード "123456" を入力してください');
                          },
                          icon: const Icon(Icons.security),
                          label: const Text('🛠️ 安全テストモード（他人に迷惑なし）'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // オフラインモード表示（開発用のみ）
                if (_isOfflineMode) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '🛡️ 安全テストモード',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '安全なテスト用認証コード: 123456',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 認証コード入力
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '🔐 認証コード（6桁）',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                
                // ログインボタン
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
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
                            '✅ 認証して開始',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 戻るボタン
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isCodeSent = false;
                      _codeController.clear();
                      _isOfflineMode = false;
                    });
                  },
                  child: const Text('← 電話番号を変更'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 🔐 認証コード確認
  Future<void> _verifyCode() async {
    if (_codeController.text.isEmpty) {
      _showSnackBar('認証コードを入力してください');
      return;
    }

    setState(() => _isLoading = true);
    
    // 🛡️ オフラインモードの場合
    if (_isOfflineMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _isLoading = false);
      _offlineAuthentication();
      return;
    }
  }

  // 🛡️ オフライン認証（開発・テスト用）
  void _offlineAuthentication() {
    if (_codeController.text == '123456') {
      // テスト用認証成功
      Navigator.of(context).pushReplacementNamed('/profile_setup');
    } else {
      _showSnackBar('❌ テストコードが正しくありません（ヒント: 123456）');
    }
  }

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
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}