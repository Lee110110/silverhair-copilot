import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/platform_channels/overlay_channel.dart';

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen> {
  bool _overlayPermission = false;
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check permissions when returning from system settings
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPerm = await OverlayChannel.checkPermission();
    final active = await OverlayChannel.isOverlayActive();
    if (mounted) {
      setState(() {
        _overlayPermission = hasPerm;
        _overlayActive = active;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('权限设置')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '为了正常使用SOS求助功能，需要开启以下权限：',
              style: TextStyle(fontSize: AppTheme.fontSizeBody, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Step 1: Overlay permission
            _buildStepCard(
              step: 1,
              title: '浮窗权限',
              description: _overlayPermission
                  ? '已开启'
                  : '点击后跳转到系统设置，找到「显示在其他应用上层」并开启',
              isDone: _overlayPermission,
              onTap: () async {
                await OverlayChannel.requestPermission();
                // Delay then re-check since user must return from settings
                await Future.delayed(const Duration(milliseconds: 500));
                await _checkPermissions();
              },
            ),
            const SizedBox(height: 16),

            // Step 2: Start overlay service
            _buildStepCard(
              step: 2,
              title: '开启SOS守护',
              description: _overlayActive ? 'SOS浮窗已开启' : '需要先完成第1步',
              isDone: _overlayActive,
              onTap: _overlayPermission ? () async {
                await OverlayChannel.showOverlay();
                await Future.delayed(const Duration(milliseconds: 500));
                await _checkPermissions();
              } : null,
            ),
            const SizedBox(height: 32),

            // Re-check button
            if (!_overlayPermission || !_overlayActive)
              OutlinedButton.icon(
                onPressed: _checkPermissions,
                icon: const Icon(Icons.refresh),
                label: const Text('重新检查权限', style: TextStyle(fontSize: 20)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, AppTheme.buttonHeight + 4),
                  side: const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            const SizedBox(height: 16),

            // Back to home
            SizedBox(
              height: AppTheme.buttonHeight + 8,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                child: const Text('完成设置', style: TextStyle(fontSize: 24, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String description,
    required bool isDone,
    required VoidCallback? onTap,
  }) {
    return Card(
      color: isDone ? const Color(0xFFE8F5E9) : Colors.white,
      child: InkWell(
        onTap: isDone ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingLarge),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDone ? AppTheme.secondary : AppTheme.primary,
                child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 28)
                  : Text('$step', style: const TextStyle(fontSize: 24, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: AppTheme.fontSizeBody, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(fontSize: AppTheme.fontSizeCaption, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (!isDone) const Icon(Icons.arrow_forward_ios, color: AppTheme.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}