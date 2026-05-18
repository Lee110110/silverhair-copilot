import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

class SosProvider extends ChangeNotifier {
  Map<String, dynamic>? _latestAlert;
  bool _hasAlert = false;
  Timer? _pollTimer;

  bool get hasAlert => _hasAlert;
  Map<String, dynamic>? get latestAlert => _latestAlert;

  void startPolling() {
    _pollTimer?.cancel();
    _checkSos();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkSos());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkSos() async {
    try {
      final list = await ApiClient.getList('/sos/history?limit=1');
      if (list != null && list.isNotEmpty) {
        final latest = list[0] as Map<String, dynamic>;
        if (latest['status'] == 'alerting') {
          _latestAlert = latest;
          _hasAlert = true;
          notifyListeners();
          return;
        }
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        stopPolling();
        return;
      }
    } catch (_) {}
    if (_hasAlert) {
      _hasAlert = false;
      _latestAlert = null;
      notifyListeners();
    }
  }

  Future<bool> acceptSos(String sosId) async {
    try {
      final resp = await ApiClient.put('/sos/$sosId/accept');
      if (resp != null) {
        _hasAlert = false;
        _latestAlert = null;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
