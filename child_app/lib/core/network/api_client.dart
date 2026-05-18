import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final bool isUnauthorized;
  ApiException(this.message, {this.statusCode, this.isUnauthorized = false});
  @override
  String toString() => message;
}

typedef OnUnauthorizedCallback = Future<void> Function();

class ApiClient {
  static final String _baseUrl = ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 10);
  static OnUnauthorizedCallback? onUnauthorized;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String? _extractError(http.Response resp) {
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return body['detail'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Never _throwResponse(http.Response resp) {
    if (resp.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException(
        _extractError(resp) ?? '登录已过期，请重新登录',
        statusCode: resp.statusCode,
        isUnauthorized: true,
      );
    }
    throw ApiException(
      _extractError(resp) ?? '请求失败 (${resp.statusCode})',
      statusCode: resp.statusCode,
    );
  }

  static Future<Map<String, dynamic>?> get(String path) async {
    final headers = await _headers();
    final resp = await http
        .get(Uri.parse('$_baseUrl$path'), headers: headers)
        .timeout(_timeout);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    _throwResponse(resp);
  }

  static Future<List<dynamic>?> getList(String path) async {
    final headers = await _headers();
    final resp = await http
        .get(Uri.parse('$_baseUrl$path'), headers: headers)
        .timeout(_timeout);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    _throwResponse(resp);
  }

  static Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    final headers = await _headers();
    final resp = await http
        .post(Uri.parse('$_baseUrl$path'), headers: headers, body: jsonEncode(data))
        .timeout(_timeout);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    _throwResponse(resp);
  }

  static Future<Map<String, dynamic>?> put(String path, [Map<String, dynamic>? data]) async {
    final headers = await _headers();
    final resp = await http
        .put(Uri.parse('$_baseUrl$path'), headers: headers, body: data != null ? jsonEncode(data) : null)
        .timeout(_timeout);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    _throwResponse(resp);
  }
}
