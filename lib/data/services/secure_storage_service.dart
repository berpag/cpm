// lib/data/services/secure_storage_service.dart

import 'dart:convert'; // <-- IMPORT AÑADIDO
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // --- Métodos para API Keys de Exchanges ---
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

  // --- ¡NUEVOS MÉTODOS GENÉRICOS PARA WALLETS MULTI-CADENA! ---

  /// Guarda un mapa de redes y sus direcciones para una wallet específica.
  static Future<void> saveWalletNetworks(String walletName, Map<String, String> networks) async {
    final jsonString = json.encode(networks);
    await _storage.write(key: '${walletName}_networks', value: jsonString);
  }

  /// Obtiene el mapa de redes y direcciones para una wallet.
  static Future<Map<String, String>> getWalletNetworks(String walletName) async {
    final jsonString = await _storage.read(key: '${walletName}_networks');
    if (jsonString != null) {
      return Map<String, String>.from(json.decode(jsonString));
    }
    return {}; // Devuelve un mapa vacío si no hay nada guardado
  }
}