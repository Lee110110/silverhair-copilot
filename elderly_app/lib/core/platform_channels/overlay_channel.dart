import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';

class OverlayChannel {
  static const MethodChannel _channel = MethodChannel('overlay_service');

  static void Function()? onSosClicked;

  static void setupListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSosClicked') {
        onSosClicked?.call();
        await _sendSosAlert();
      }
    });
  }

  /// Check if SYSTEM_ALERT_WINDOW permission is granted
  static Future<bool> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Request SYSTEM_ALERT_WINDOW permission (opens system settings)
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Show the SOS floating overlay button
  static Future<bool> showOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('showOverlay');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Hide the SOS floating overlay button
  static Future<bool> hideOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('hideOverlay');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if overlay is currently active
  static Future<bool> isOverlayActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayActive');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Update SOS button visual state
  static Future<void> updateSosStatus(String status) async {
    try {
      await _channel.invokeMethod<void>('updateSosStatus', {'status': status});
    } on PlatformException {
      // Ignore
    }
  }

  /// Send SOS alert to backend
  static Future<void> _sendSosAlert() async {
    try {
      await OverlayChannel.updateSosStatus('alerting');
      await ApiClient.post('/sos/alert', {});
      await OverlayChannel.updateSosStatus('sent');
    } catch (e) {
      await OverlayChannel.updateSosStatus('error');
    }
  }
}
