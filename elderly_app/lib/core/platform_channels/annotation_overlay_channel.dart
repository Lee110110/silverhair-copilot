import 'dart:convert';
import 'package:flutter/services.dart';

class AnnotationOverlayChannel {
  static const MethodChannel _channel = MethodChannel('annotation_overlay');

  /// Render an annotation on the overlay
  static Future<bool> renderAnnotation(String type, Map<String, dynamic> payload) async {
    try {
      final result = await _channel.invokeMethod<bool>('renderAnnotation', {
        'type': type,
        'payload': jsonEncode(payload),
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Clear all annotations
  static Future<bool> clearAnnotations() async {
    try {
      final result = await _channel.invokeMethod<bool>('clearAnnotations');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Show the annotation overlay
  static Future<bool> showOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('showOverlay');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Hide the annotation overlay
  static Future<bool> hideOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('hideOverlay');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
