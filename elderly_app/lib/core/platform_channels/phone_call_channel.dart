import 'package:flutter/services.dart';

class PhoneCallChannel {
  static const MethodChannel _channel = MethodChannel('phone_call');

  /// Make a direct phone call
  static Future<bool> makeCall(String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod<bool>('makeCall', {'phoneNumber': phoneNumber});
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}