import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

class CoScreenListener extends ChangeNotifier {
  Timer? _pollTimer;
  String? _pendingSessionId;
  bool _hasIncomingRequest = false;
  bool _initialized = false;

  bool get hasIncomingRequest => _hasIncomingRequest;
  String? get pendingSessionId => _pendingSessionId;

  void startListening() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkForSessions());
    _checkForSessions();
  }

  void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkForSessions() async {
    try {
      final resp = await ApiClient.get('/coscreen/pending');
      if (resp != null && resp['session_id'] != null) {
        final sessionId = resp['session_id'] as String;
        if (!_initialized) {
          _pendingSessionId = sessionId;
          _initialized = true;
          debugPrint('CoScreenListener: initialized with existing session=$sessionId');
          return;
        }
        if (sessionId != _pendingSessionId) {
          _pendingSessionId = sessionId;
          _hasIncomingRequest = true;
          debugPrint('CoScreenListener: NEW pending session=$sessionId');
          notifyListeners();
        }
      } else {
        if (!_initialized) {
          _initialized = true;
        }
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        debugPrint('CoScreenListener: auth expired, stopping poll');
        stopListening();
        return;
      }
      debugPrint('CoScreenListener error: $e');
    } catch (e) {
      debugPrint('CoScreenListener error: $e');
    }
  }

  void clearIncomingRequest() {
    _hasIncomingRequest = false;
    notifyListeners();
  }
}
