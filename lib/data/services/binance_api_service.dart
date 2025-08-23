// lib/data/services/binance_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

class BinanceApiService {
  static const String _baseUrl = 'https://api.binance.com';

  // Esta función sirve para verificar que las claves son correctas.
  // Si tiene éxito, devuelve la información de la cuenta. Si falla, lanza una excepción.
  static Future<Map<String, dynamic>> getAccountInfo({
    required String apiKey,
    required String secretKey,
  }) async {
    const endpoint = '/api/v3/account';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final params = 'timestamp=$timestamp';

    final signature = _generateSignature(params, secretKey);
    final url = Uri.parse('$_baseUrl$endpoint?$params&signature=$signature');

    print("[Binance API] Verificando claves con una llamada a la cuenta...");

    try {
      final response = await http.get(
        url,
        headers: {'X-MBX-APIKEY': apiKey},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        print("[Binance API] Verificación exitosa.");
        return data;
      } else {
        // Si Binance devuelve un error, lo lanzamos para que la UI lo atrape
        print("[Binance API] Error de Binance: ${data['msg']}");
        throw Exception('Error de Binance: ${data['msg']}');
      }
    } catch (e) {
      print("[Binance API] Fallo en la conexión: $e");
      throw Exception('No se pudo conectar con Binance. Revisa tu conexión a internet.');
    }
  }

  // --- LÓGICA DE FIRMA CRIPTOGRÁFICA ---
  // Este es el método estándar para autenticarse en la API de Binance
  static String _generateSignature(String params, String secretKey) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(params);

    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return hex.encode(digest.bytes);
  }

  // TODO: En el futuro, aquí irán las funciones para obtener trades, depósitos, etc.
}