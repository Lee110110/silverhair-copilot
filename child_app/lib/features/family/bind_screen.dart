import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';

class BindScreen extends StatefulWidget {
  const BindScreen({super.key});

  @override
  State<BindScreen> createState() => _BindScreenState();
}

class _BindScreenState extends State<BindScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  Future<void> _bind() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showTip('请输入邀请码');
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient.post('/family-links/request', {
        'invite_code': code,
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on TimeoutException {
      _showTip('连接超时，请检查网络');
    } on ApiException catch (e) {
      _showTip(e.message);
    } catch (_) {
      _showTip('网络连接失败，请检查服务器地址');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showTip(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('绑定老人')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.link, size: 64, color: AppTheme.primary),
            const SizedBox(height: 24),
            const Text(
              '请在老人手机上打开"银发陪驾"App，\n点击生成邀请码后输入',
              style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 8),
              decoration: const InputDecoration(
                labelText: '邀请码',
                hintText: '请输入6位邀请码',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: AppTheme.buttonHeight + 8,
              child: ElevatedButton(
                onPressed: _loading ? null : _bind,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('绑定', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
