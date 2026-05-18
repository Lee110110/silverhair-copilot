import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/network/ws_client.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/network/protocol.dart';

class CoScreenController extends ChangeNotifier {
  WsClient? _wsClient;
  String? _sessionId;
  bool _isConnected = false;
  bool _isSessionReady = false;
  bool _isPeerDisconnected = false;
  String? _childId;

  // Frame data for rendering
  Uint8List? _currentFrame;
  int _frameSeq = 0;

  // Annotation data
  final List<AnnotationPoint> _currentStroke = [];
  final List<List<AnnotationPoint>> _strokes = [];

  bool get isConnected => _isConnected;
  bool get isSessionReady => _isSessionReady;
  bool get isPeerDisconnected => _isPeerDisconnected;
  String? get sessionId => _sessionId;
  Uint8List? get currentFrame => _currentFrame;
  int get frameSeq => _frameSeq;
  List<List<AnnotationPoint>> get strokes => _strokes;
  List<AnnotationPoint> get currentStroke => _currentStroke;

  /// Start co-screen: create session via REST, then connect WebSocket
  Future<bool> startSession(String elderlyId) async {
    try {
      final resp = await ApiClient.post('/coscreen/session', {
        'elderly_id': elderlyId,
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

        _wsClient!.send(Protocol.createMessage(
          type: Protocol.sessionJoin,
          sessionId: _sessionId!,
          payload: {'role': 'child', 'user_id': _childId},
        ));
      },
      onDisconnected: () {
        _isConnected = false;
        _isSessionReady = false;
        notifyListeners();
      },
    );

    _wsClient!.connect();
  }

  /// Send annotation stroke point to elderly
  void sendAnnotationStart(double normX, double normY) {
    if (_wsClient == null || !_isConnected) return;
    _wsClient!.send(Protocol.createMessage(
      type: Protocol.annotationStart,
      sessionId: _sessionId!,
      payload: {'x': normX, 'y': normY, 'color': '#FF0000', 'width': 4.0},
    ));
  }

  void sendAnnotationStroke(double normX, double normY) {
    if (_wsClient == null || !_isConnected) return;
    _wsClient!.send(Protocol.createMessage(
      type: Protocol.annotationStroke,
      sessionId: _sessionId!,
      payload: {'x': normX, 'y': normY},
    ));
  }

  void sendAnnotationEnd() {
    if (_wsClient == null || !_isConnected) return;
    _wsClient!.send(Protocol.createMessage(
      type: Protocol.annotationEnd,
      sessionId: _sessionId!,
      payload: {},
    ));
  }

  void sendAnnotationClear() {
    if (_wsClient == null || !_isConnected) return;
    _wsClient!.send(Protocol.createMessage(
      type: Protocol.annotationClear,
      sessionId: _sessionId!,
      payload: {},
    ));
  }

  /// Add local annotation point for rendering
  void addLocalAnnotationPoint(double normX, double normY, bool isStart) {
    if (isStart) {
      if (_currentStroke.isNotEmpty) {
        _strokes.add(List.from(_currentStroke));
      }
      _currentStroke.clear();
    }
    _currentStroke.add(AnnotationPoint(normX, normY));
    notifyListeners();
  }

  void finishLocalStroke() {
    if (_currentStroke.isNotEmpty) {
      _strokes.add(List.from(_currentStroke));
      _currentStroke.clear();
      notifyListeners();
    }
  }

  void clearLocalAnnotations() {
    _strokes.clear();
    _currentStroke.clear();
    notifyListeners();
  }

  /// End the session
  Future<void> endSession() async {
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
    _isSessionReady = false;
    _sessionId = null;
    _currentFrame = null;
    _strokes.clear();
    _currentStroke.clear();

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
        _isSessionReady = true;
        _isPeerDisconnected = false;
        notifyListeners();
        break;

      case Protocol.frameScreen:
        _handleFrame(msg);
        break;

      case Protocol.annotationStart:
      case Protocol.annotationStroke:
      case Protocol.annotationEnd:
      case Protocol.annotationClear:
      case Protocol.annotationClearAll:
        // These come from the elderly's echo-back; we already render locally
        break;

      case Protocol.frameAck:
        break;

      case Protocol.heartbeatPong:
        break;

      case Protocol.sessionEnd:
        endSession();
        break;

      case Protocol.sessionPeerDisconnect:
        _isPeerDisconnected = true;
        notifyListeners();
        break;
    }
  }

  void _handleFrame(Map<String, dynamic> msg) {
    final payload = msg['payload'] as Map<String, dynamic>? ?? {};
    final base64Data = payload['data'] as String?;
    if (base64Data != null) {
      _currentFrame = base64Decode(base64Data);
      _frameSeq++;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _wsClient?.close();
    super.dispose();
  }
}

class AnnotationPoint {
  final double x;
  final double y;
  AnnotationPoint(this.x, this.y);
}
