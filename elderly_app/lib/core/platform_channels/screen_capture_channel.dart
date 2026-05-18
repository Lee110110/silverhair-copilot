import 'package:flutter/services.dart';

class ScreenCaptureChannel {
  static const MethodChannel _methodChannel = MethodChannel('screen_capture');
  static const EventChannel _eventChannel = EventChannel('screen_capture_frames');

  /// Start screen capture (requests MediaProjection permission)
  static Future<bool> startCapture() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startCapture');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stop screen capture
  static Future<bool> stopCapture() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopCapture');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if screen capture is currently running
  static Future<bool> isCapturing() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isCapturing');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stream screen frames as JPEG byte arrays
  static Stream<Uint8List> get frameStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event as Uint8List);
  }
}