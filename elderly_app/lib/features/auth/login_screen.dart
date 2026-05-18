import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  int _countdown = 0;

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      _showTip('请输入正确的手机号');
      return;
    }
    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final ok = await auth.sendSmsCode(phone);
    setState(() {
      _loading = false;
      _codeSent = ok;
      if (ok) {
        _countdown = 60;
        _startCountdown();
      }
    });
    if (!ok) _showTip('验证码发送失败，请重试');
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.length != 11) { _showTip('请输入正确的手机号'); return; }
    if (code.length < 4) { _showTip('请输入验证码'); return; }

    setState(() => _loading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final ok = await auth.loginWithPhone(phone, code);
    setState(() => _loading = false);

    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/permissions');
    } else if (mounted) {
      _showTip('登录失败，请检查验证码');
    }
  }

  void _showTip(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: AppTheme.fontSizeBody))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 80, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('银发陪驾', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 8),
              const Text('有人陪，不害怕', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
              const SizedBox(height: 48),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                decoration: const InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入您的手机号',
                  prefixIcon: Icon(Icons.phone_android, size: AppTheme.iconSize),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(fontSize: AppTheme.fontSizeBody),
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        hintText: '请输入验证码',
                        prefixIcon: Icon(Icons.sms, size: AppTheme.iconSize),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    height: AppTheme.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _countdown > 0 ? null : (_loading ? null : _sendCode),
                      child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight + 8,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('登录', style: TextStyle(fontSize: 24, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}