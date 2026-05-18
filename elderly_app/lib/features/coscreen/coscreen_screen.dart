import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/ws_client.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/protocol.dart';
import '../../core/platform_channels/screen_capture_channel.dart';
import '../../core/platform_channels/annotation_overlay_channel.dart';
import '../auth/auth_service.dart';

class ElderlyCoScreenScreen extends StatefulWidget {
  final String sessionId;
  const ElderlyCoScreenScreen({super.key, required this.sessionId});

  @override
  State<ElderlyCoScreenScreen> createState() => _ElderlyCoScreenScreenState();
}

class _ElderlyCoScreenScreenState extends State<ElderlyCoScreenScreen> {
  WsClient? _wsClient;
  bool _isConnected = false;
  bool _requestingCapture = true;
  String? _error;
  StreamSubscription? _frameSubscription;

  @override
  void initState() {
    super.initState();
    // Step 1: Request screen capture FIRST (before WS, so the permission
    // dialog doesn't kill an active WebSocket connection)
    _requestScreenCapture();
  }

  Future<void> _requestScreenCapture() async {
    // Always stop any previous capture first — the service may have been
    // killed by the system (aggressive OEM battery optimisation on Redmi,
    // Xiaomi, etc.) without onDestroy resetting the isRunning flag.
    await ScreenCaptureChannel.stopCapture();
    await Future.delayed(const Duration(milliseconds: 300));

    final captureOk = await ScreenCaptureChannel.startCapture();

    if (!captureOk) {
      if (mounted) {
        setState(() {
          _requestingCapture = false;
          _error = '屏幕采集启动失败，请允许录屏权限';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _requestingCapture = false;
      });
    }

    // Step 2: Now that capture is running, connect WebSocket
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final token = auth.token;
    if (token == null) {
      setState(() { _error = '未登录'; });
      return;
    }

    final wsUrl = '${ApiConfig.wsBaseUrl}/ws/coscreen/${widget.sessionId}?token=$token';

    _wsClient = WsClient(
      url: wsUrl,
      onMessage: _handleMessage,
      onConnected: () {
        if (!mounted) return;
        setState(() => _isConnected = true);

        _wsClient!.send(Protocol.createMessage(
          type: Protocol.sessionJoin,
          sessionId: widget.sessionId,
          payload: {'role': 'elderly', 'user_id': auth.user?['id']},
        ));
      },
      onDisconnected: () {
        if (mounted) setState(() => _isConnected = false);
      },
    );

    _wsClient!.connect();

    // Start pushing frames
    _startPushingFrames();
  }

  void _startPushingFrames() {
    _frameSubscription = ScreenCaptureChannel.frameStream.listen((frameBytes) {
      if (_wsClient != null && _isConnected) {
        final base64Frame = base64Encode(frameBytes);
        _wsClient!.send(Protocol.createMessage(
          type: Protocol.frameScreen,
          sessionId: widget.sessionId,
          payload: {
            'data': base64Frame,
            'seq': DateTime.now().millisecondsSinceEpoch,
            'width': 1080,
            'height': 1920,
          },
        ));
      }
    });
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    switch (type) {
      case Protocol.sessionReady:
        if (mounted) setState(() => _isConnected = true);
        break;

      case Protocol.sessionPeerDisconnect:
        // Child temporarily disconnected; our WS auto-reconnects, just update UI
        if (mounted) setState(() => _isConnected = false);
        break;

      case Protocol.annotationStart:
      case Protocol.annotationStroke:
      case Protocol.annotationEnd:
      case Protocol.annotationClear:
      case Protocol.annotationClearAll:
        final payload = msg['payload'] as Map<String, dynamic>? ?? {};
        AnnotationOverlayChannel.renderAnnotation(msg['type'] as String, payload);
        break;

      case Protocol.sessionEnd:
        _endSession();
        break;
    }
  }

  Future<void> _endSession() async {
    _frameSubscription?.cancel();
    await ScreenCaptureChannel.stopCapture();

    _wsClient?.send(Protocol.createMessage(
      type: Protocol.sessionEnd,
      sessionId: widget.sessionId,
      payload: {'reason': 'user_quit'},
    ));
    _wsClient?.close();

    try {
      await ApiClient.put('/coscreen/session/${widget.sessionId}/end');
    } catch (_) {}

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    ScreenCaptureChannel.stopCapture();
    _wsClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程协助中'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error != null) ...[
              const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.danger), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('返回')),
            ] else if (_requestingCapture) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('请允许录屏权限', style: TextStyle(fontSize: AppTheme.fontSizeTitle, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('系统将弹出录屏授权弹窗，请点击「立即开始」', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            ] else ...[
              Icon(
                _isConnected ? Icons.screen_share : Icons.wifi_tethering,
                size: 80,
                color: _isConnected ? AppTheme.secondary : AppTheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _isConnected ? '正在共享屏幕' : '正在连接...',
                style: const TextStyle(fontSize: AppTheme.fontSizeTitle, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _isConnected
                  ? '子女正在查看您的屏幕，可以在您屏幕上画标注指引操作'
                  : '请稍候...',
                style: const TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight + 12,
                child: ElevatedButton(
                  onPressed: _endSession,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                  child: const Text('结束共享', style: TextStyle(fontSize: 24, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
