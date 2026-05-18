import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/network/api_config.dart';

class AuthService extends ChangeNotifier {
  String? _token;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  String? _phone;

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get phone => _phone;
  String? get inviteCode => _user?['invite_code'];
  Map<String, dynamic>? get user => _user;

  static final String _baseUrl = ApiConfig.baseUrl;

  Future<void> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _user = jsonDecode(userJson);
    }
    _phone = prefs.getString('phone');
    notifyListeners();
  }

  Future<bool> sendSmsCode(String phone) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/sms/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> loginWithPhone(String phone, String code) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/login/phone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'code': code}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _token = data['access_token'];
        _refreshToken = data['refresh_token'];
        _user = data['user'];
        _phone = phone;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _token!);
        await prefs.setString('refresh_token', _refreshToken!);
        await prefs.setString('user', jsonEncode(_user));
        await prefs.setString('phone', phone);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _refreshToken = null;
    _user = null;
    _phone = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user');
    await prefs.remove('phone');
    notifyListeners();
  }
}