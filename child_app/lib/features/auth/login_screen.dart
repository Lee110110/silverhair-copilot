import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_config.dart';
import '../auth/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  int _countdown = 0;

  Future<void> _testConnection() async {
    final url = '${ApiConfig.baseUrl}/auth/sms/send';
    final wsUrl = ApiConfig.wsBaseUrl;
    debugPrint('[Diag] Testing connection to $url ...');
    debugPrint('[Diag] Base URL: ${ApiConfig.baseUrl}');
    debugPrint('[Diag] WS URL: $wsUrl');
    _showTip('正在测试连接 $url ...');
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': '13800000000'}),
      ).timeout(const Duration(seconds: 5));
      debugPrint('[Diag] Response: ${resp.statusCode} ${resp.body}');
      if (resp.statusCode == 200 || resp.statusCode == 422) {
        _showTip('连接成功! 状态码: ${resp.statusCode}');
      } else {
        _showTip('服务器返回: HTTP ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('[Diag] Connection failed: $e');
      _showTip('连接失败: $e');
    }
  }

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
      if (ok) {
        _countdown = 60;
        _startCountdown();
      }
    });
    if (!ok) _showTip('验证码发送失败: ${auth.lastError ?? "请重试"}');
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
      Navigator.pushReplacementNamed(context, '/home');
    } else if (mounted) {
      _showTip('登录失败: ${auth.lastError ?? "请检查验证码"}');
    }
  }

  void _showTip(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: AppTheme.fontSizeBody)),
        duration: const Duration(seconds: 5),
      ),
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
              const Icon(Icons.shield, size: 72, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('银发陪驾 · 子女版', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 8),
              const Text('守护家人，随时响应', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
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
                    width: 120,
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
                    : const Text('登录', style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loading ? null : _testConnection,
                icon: const Icon(Icons.network_check),
                label: const Text('测试服务器连接'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
