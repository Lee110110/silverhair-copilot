import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../../core/network/api_client.dart';
import '../../core/platform_channels/overlay_channel.dart';
import '../coscreen/coscreen_listener.dart';
import '../coscreen/coscreen_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _overlayActive = false;
  CoScreenListener? _coScreenListener;

  @override
  void initState() {
    super.initState();
    _startCoScreenListening();
    OverlayChannel.setupListener();
    _autoEnableOverlay();
  }

  /// 自动尝试开启SOS浮窗：已开启则跳过，有权限则直接开启，无权限则引导
  Future<void> _autoEnableOverlay() async {
    // 先重置可能过期的状态：如果 Kotlin 静态变量 isRunning=true 但服务已死，
    // 先尝试 hide 再重新 show
    final active = await OverlayChannel.isOverlayActive();
    if (active) {
      // 验证服务是否真的在运行——尝试 hide 后立即 show
      await OverlayChannel.hideOverlay();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    final hasPermission = await OverlayChannel.checkPermission();
    if (hasPermission) {
      await OverlayChannel.showOverlay();
      // 等待服务启动
      await Future.delayed(const Duration(milliseconds: 500));
      final nowActive = await OverlayChannel.isOverlayActive();
      setState(() => _overlayActive = nowActive);
      if (!nowActive && mounted) {
        // showOverlay 失败，跳转权限设置页
        Navigator.pushNamed(context, '/permissions');
      }
    } else {
      // 无浮窗权限，跳转到权限设置页引导用户
      if (mounted) {
        Navigator.pushNamed(context, '/permissions');
      }
    }
  }

  Future<void> _checkOverlayStatus() async {
    final active = await OverlayChannel.isOverlayActive();
    setState(() => _overlayActive = active);
  }

  void _startCoScreenListening() {
    _coScreenListener = CoScreenListener();
    _coScreenListener!.addListener(_onCoScreenRequest);
    _coScreenListener!.startListening();
  }

  void _onCoScreenRequest() {
    if (_coScreenListener!.hasIncomingRequest) {
      _showAcceptDialog(_coScreenListener!.pendingSessionId!);
    }
  }

  void _showAcceptDialog(String sessionId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('共屏请求', style: TextStyle(fontSize: 28)),
        content: const Text('您的家人请求远程协助，是否接受？', style: TextStyle(fontSize: 22)),
        actions: [
          TextButton(
            onPressed: () {
              _coScreenListener!.clearIncomingRequest();
              Navigator.pop(ctx);
            },
            child: const Text('拒绝', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            onPressed: () {
              _coScreenListener!.clearIncomingRequest();
              Navigator.pop(ctx);
              _acceptCoScreen(sessionId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
            child: const Text('接受', style: TextStyle(fontSize: 20, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptCoScreen(String sessionId) async {
    try {
      await ApiClient.put('/coscreen/session/$sessionId/accept');
    } catch (_) {}
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ElderlyCoScreenScreen(sessionId: sessionId),
      ),
    );
  }

  Future<void> _toggleOverlay() async {
    try {
      if (_overlayActive) {
        await OverlayChannel.hideOverlay();
      } else {
        await OverlayChannel.showOverlay();
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await _checkOverlayStatus();
    } catch (e) {
      // 如果出错，重新检查状态
      await _checkOverlayStatus();
    }
  }

  @override
  void dispose() {
    _coScreenListener?.stopListening();
    _coScreenListener?.removeListener(_onCoScreenRequest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('银发陪驾')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                child: Column(
                  children: [
                    Icon(
                      _overlayActive ? Icons.check_circle : Icons.cancel,
                      size: 56,
                      color: _overlayActive ? AppTheme.secondary : AppTheme.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _overlayActive ? 'SOS守护已开启' : 'SOS守护未开启',
                      style: const TextStyle(fontSize: AppTheme.fontSizeTitle, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _overlayActive ? '遇到困难时，按屏幕上的SOS按钮即可求助' : '请先开启SOS浮窗守护',
                      style: const TextStyle(fontSize: AppTheme.fontSizeCaption, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Toggle SOS overlay button
            SizedBox(
              height: AppTheme.buttonHeight + 12,
              child: ElevatedButton(
                onPressed: _toggleOverlay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _overlayActive ? AppTheme.danger : AppTheme.secondary,
                ),
                child: Text(
                  _overlayActive ? '关闭SOS浮窗' : '开启SOS浮窗',
                  style: const TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Invite code card
            if (auth.inviteCode != null) ...[
              Card(
                color: const Color(0xFFFFF8E1),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.paddingLarge),
                  child: Column(
                    children: [
                      const Icon(Icons.person_pin, size: 40, color: AppTheme.primary),
                      const SizedBox(height: 8),
                      const Text(
                        '我的邀请码',
                        style: TextStyle(fontSize: AppTheme.fontSizeCaption, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        auth.inviteCode!,
                        style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 8, color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '告诉子女此邀请码，即可建立守护关系',
                        style: TextStyle(fontSize: AppTheme.fontSizeCaption, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Permission setup
            if (!_overlayActive)
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/permissions'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, AppTheme.buttonHeight + 4),
                  side: const BorderSide(color: AppTheme.primary, width: 2),
                ),
                child: const Text('设置权限', style: TextStyle(fontSize: AppTheme.fontSizeButton)),
              ),

            const Spacer(),

            // Logout
            TextButton(
              onPressed: () => auth.logout(),
              child: const Text('退出登录', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}