import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/network/ws_client.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/protocol.dart';
import '../../core/platform_channels/screen_capture_channel.dart';
import '../../core/platform_channels/annotation_overlay_channel.dart';

class CoScreenController extends ChangeNotifier {
  WsClient? _wsClient;
  String? _sessionId;
  bool _isConnected = false;
  bool _isCapturing = false;
  String? _elderlyId;
  String? _childId;

  bool get isConnected => _isConnected;
  bool get isCapturing => _isCapturing;
  String? get sessionId => _sessionId;

  /// Start session with an existing session ID (e.g. from incoming request)
  void startSessionWithId(String sessionId) {
    _sessionId = sessionId;
    notifyListeners();
  }

  /// Start co-screen session: create session via REST, then connect WebSocket
  Future<bool> startSession(String elderlyId) async {
    _elderlyId = elderlyId;

    try {
      // Create session via REST API
      final resp = await ApiClient.post('/coscreen/session', {
        'elderly_id': elderlyId,
        'child_id': elderlyId, // TODO: Get current user ID from auth
      });

      if (resp == null) return false;

      _sessionId = resp['id'];
      _childId = resp['child_id'];
      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Connect to WebSocket for the session
  Future<void> connectWebSocket(String token) async {
    if (_sessionId == null) return;

    final wsUrl = '${ApiConfig.wsBaseUrl}/ws/coscreen/$_sessionId?token=$token';

    _wsClient = WsClient(
      url: wsUrl,
      onMessage: _handleMessage,
      onConnected: () {
        _isConnected = true;
        notifyListeners();

        // Send join message
        _wsClient!.send(Protocol.createMessage(
          type: Protocol.sessionJoin,
          sessionId: _sessionId!,
          payload: {'role': 'elderly', 'user_id': _elderlyId},
        ));

        // Start screen capture
        _startCapture();
      },
      onDisconnected: () {
        _isConnected = false;
        notifyListeners();
      },
    );

    _wsClient!.connect();
  }

  /// Start screen capture and push frames via WebSocket
  Future<void> _startCapture() async {
    final ok = await ScreenCaptureChannel.startCapture();
    if (!ok) return;

    _isCapturing = true;
    notifyListeners();

    // Listen to frame stream and push to WebSocket
    ScreenCaptureChannel.frameStream.listen((frameBytes) {
      if (_wsClient != null && _isConnected) {
        final base64Frame = base64Encode(frameBytes);
        _wsClient!.send(Protocol.createMessage(
          type: Protocol.frameScreen,
          sessionId: _sessionId!,
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

  /// Stop screen capture and disconnect WebSocket
  Future<void> endSession() async {
    await ScreenCaptureChannel.stopCapture();
    _isCapturing = false;

    final sid = _sessionId;

    if (_wsClient != null && sid != null) {
      _wsClient!.send(Protocol.createMessage(
        type: Protocol.sessionEnd,
        sessionId: sid,
        payload: {'reason': 'user_quit'},
      ));
      _wsClient!.close();
    }

    _isConnected = false;
    _sessionId = null;

    // End session via REST
    if (sid != null) {
      try {
        await ApiClient.put('/coscreen/session/$sid/end');
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    switch (type) {
      case Protocol.sessionReady:
        _isConnected = true;
        notifyListeners();
        break;

      case Protocol.annotationStart:
      case Protocol.annotationStroke:
      case Protocol.annotationEnd:
      case Protocol.annotationClear:
      case Protocol.annotationClearAll:
        // Forward annotation data to native overlay via MethodChannel
        _forwardAnnotationToOverlay(msg);
        break;

      case Protocol.frameAck:
        // Frame acknowledgment from child - could adjust frame rate
        break;

      case Protocol.heartbeatPong:
        // Heartbeat response
        break;

      case Protocol.sessionEnd:
        endSession();
        break;
    }
  }

  /// Forward annotation data to the native overlay renderer
  void _forwardAnnotationToOverlay(Map<String, dynamic> msg) {
    final payload = msg['payload'] as Map<String, dynamic>? ?? {};
    AnnotationOverlayChannel.renderAnnotation(msg['type'] as String, payload);
  }
}