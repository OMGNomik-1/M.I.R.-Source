import 'dart:io';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;

class CustomHttpClient {
  static IOClient? _client;

  static IOClient get client {
    if (_client != null) return _client!;

    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;

    _client = IOClient(httpClient);
    return _client!;
  }

  // Удалён дублирующийся метод send, оставлен только один
  static Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return client.send(request);
  }
}