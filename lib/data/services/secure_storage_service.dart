// lib/data/services/secure_storage_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveApiKey(String exchange, String apiKey) async {
    await _storage.write(key: '${exchange}_apiKey', value: apiKey);
  }

  static Future<void> saveSecretKey(String exchange, String secretKey) async {
    await _storage.write(key: '${exchange}_secretKey', value: secretKey);
  }

  static Future<String?> getApiKey(String exchange) async {
    return await _storage.read(key: '${exchange}_apiKey');
  }

  static Future<String?> getSecretKey(String exchange) async {
    return await _storage.read(key: '${exchange}_secretKey');
  }

  static Future<void> deleteKeys(String exchange) async {
    await _storage.delete(key: '${exchange}_apiKey');
    await _storage.delete(key: '${exchange}_secretKey');
  }
}