class ApiConfig {
  static const String _lanIp = '10.30.2.198';
  static const int _port = 8000;
  static const String _apiPath = '/api/v1';

  static String get baseUrl => 'http://$_lanIp:$_port$_apiPath';
  static String get wsBaseUrl => 'ws://$_lanIp:$_port$_apiPath';
}
