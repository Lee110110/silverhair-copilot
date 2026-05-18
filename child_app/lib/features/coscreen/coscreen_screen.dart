import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import 'coscreen_controller.dart';

class CoScreenScreen extends StatefulWidget {
  final String elderlyId;
  const CoScreenScreen({super.key, required this.elderlyId});

  @override
  State<CoScreenScreen> createState() => _CoScreenScreenState();
}

class _CoScreenScreenState extends State<CoScreenScreen> {
  late CoScreenController _controller;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = CoScreenController();
    _initSession();
  }

  Future<void> _initSession() async {
    final ok = await _controller.startSession(widget.elderlyId);
    if (!ok) {
      setState(() {
        _connecting = false;
        _error = '无法创建共屏会话';
      });
      return;
    }

    final token = Provider.of<AuthService>(context, listen: false).token;
    if (!mounted) return;
    if (token != null) {
      await _controller.connectWebSocket(token);
    }

    if (mounted) {
      setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    _controller.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('共屏指引'),
          actions: [
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '清除标注',
              onPressed: () {
                _controller.sendAnnotationClear();
                _controller.clearLocalAnnotations();
              },
            ),
          ],
        ),
        body: _connecting
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildCoScreen(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('返回')),
        ],
      ),
    );
  }

  Widget _buildCoScreen() {
    return Consumer<CoScreenController>(
      builder: (context, ctrl, _) {
        return Column(
          children: [
            // Connection status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: ctrl.isPeerDisconnected
                  ? Colors.orange.shade50
                  : ctrl.isSessionReady
                      ? Colors.green.shade50
                      : ctrl.isConnected
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: ctrl.isPeerDisconnected
                        ? Colors.orange
                        : ctrl.isSessionReady
                            ? Colors.green
                            : ctrl.isConnected
                                ? Colors.blue
                                : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ctrl.isPeerDisconnected
                        ? '对方暂时断开，等待重连...'
                        : ctrl.isSessionReady
                            ? '已连接 - 等待对方画面...'
                            : ctrl.isConnected
                                ? '等待老人接受...'
                                : '连接中...',
                    style: TextStyle(
                      fontSize: 14,
                      color: ctrl.isPeerDisconnected
                          ? Colors.orange.shade800
                          : ctrl.isSessionReady
                              ? Colors.green.shade800
                              : ctrl.isConnected
                                  ? Colors.blue.shade800
                                  : Colors.orange.shade800,
                    ),
                  ),
                  const Spacer(),
                  if (ctrl.currentFrame != null)
                    Text('帧: ${ctrl.frameSeq}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            // Screen + Annotation area
            Expanded(
              child: ctrl.currentFrame == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            ctrl.isPeerDisconnected
                                ? '对方暂时断开，等待重连...'
                                : ctrl.isSessionReady
                                    ? '等待对方画面...'
                                    : ctrl.isConnected
                                        ? '等待老人接受共屏请求...'
                                        : '正在连接...',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : _buildScreenWithAnnotations(ctrl),
            ),
            // Bottom toolbar
            _buildToolbar(ctrl),
          ],
        );
      },
    );
  }

  Widget _buildScreenWithAnnotations(CoScreenController ctrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) {
            final norm = _toNormalized(details.localPosition, constraints.biggest);
            ctrl.addLocalAnnotationPoint(norm.dx, norm.dy, true);
            ctrl.sendAnnotationStart(norm.dx, norm.dy);
          },
          onPanUpdate: (details) {
            final norm = _toNormalized(details.localPosition, constraints.biggest);
            ctrl.addLocalAnnotationPoint(norm.dx, norm.dy, false);
            ctrl.sendAnnotationStroke(norm.dx, norm.dy);
          },
          onPanEnd: (_) {
            ctrl.finishLocalStroke();
            ctrl.sendAnnotationEnd();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Frame layer
              Image.memory(
                ctrl.currentFrame!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
              // Annotation layer
              CustomPaint(
                painter: AnnotationPainter(
                  strokes: ctrl.strokes,
                  currentStroke: ctrl.currentStroke,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Offset _toNormalized(Offset local, Size size) {
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  Widget _buildToolbar(CoScreenController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清除标注',
            onPressed: () {
              ctrl.sendAnnotationClear();
              ctrl.clearLocalAnnotations();
            },
          ),
          ElevatedButton.icon(
            onPressed: () {
              ctrl.endSession();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.call_end),
            label: const Text('结束共屏'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

class AnnotationPainter extends CustomPainter {
  final List<List<AnnotationPoint>> strokes;
  final List<AnnotationPoint> currentStroke;

  AnnotationPainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF0000)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke, paint);
    }
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, size, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, Size size, List<AnnotationPoint> stroke, Paint paint) {
    if (stroke.length < 2) return;
    final path = Path();
    path.moveTo(stroke.first.x * size.width, stroke.first.y * size.height);
    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].x * size.width, stroke[i].y * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return true; // Always repaint when new strokes arrive
  }
}
