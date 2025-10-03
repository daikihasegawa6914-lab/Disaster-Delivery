import 'package:flutter/material.dart';
import 'main_screen.dart';

// 🔐 ハッカソン発表用シンプルログイン画面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 48),
              
              // 🛠️ デモ用認証コード入力
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
                    const SizedBox(height: 12),
                    Text(
                      '安全なテスト用認証コード: 123456',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // 認証コード入力
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: '🔐 認証コード（6桁）',
                  hintText: '123456',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              
              // 認証ボタン
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
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
              const SizedBox(height: 24),
              
              // 説明テキスト
              Text(
                'ハッカソン発表用のデモ認証です\n実際のアプリでは電話番号SMS認証を使用します',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔐 認証処理（ハッカソン発表用）
  Future<void> _authenticate() async {
    if (_codeController.text.isEmpty) {
      _showSnackBar('認証コードを入力してください');
      return;
    }

    setState(() => _isLoading = true);
    
    // デモ用の遅延
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(() => _isLoading = false);
    
    if (_codeController.text == '123456') {
      // デモ認証成功 - メイン画面へ
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else {
      _showSnackBar('❌ 認証コードが正しくありません（正解: 123456）');
    }
  }

  // 📢 メッセージ表示
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue.shade800,
        ),
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}