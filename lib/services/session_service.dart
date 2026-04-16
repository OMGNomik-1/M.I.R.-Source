import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  final _storage = const FlutterSecureStorage();

  Future<void> saveUserSession(String username) async {
    await _storage.write(key: 'username', value: username);
  }

  Future<String?> getSavedUsername() async {
    return await _storage.read(key: 'username');
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'username');
  }
}