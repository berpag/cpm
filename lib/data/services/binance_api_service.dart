// lib/data/services/binance_api_service.dart

// --- ¡IMPORTS CORREGIDOS! ---
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

class BinanceApiService {
  static const String _baseUrl = 'https://api.binance.com';
  static const String _p2pUrl = 'https://p2p.binance.com';


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
        print("[Binance API] Error de Binance: ${data['msg']}");
        throw Exception('Error de Binance: ${data['msg']}');
      }
    } catch (e) {
      print("[Binance API] Fallo en la conexión: $e");
      throw Exception('No se pudo conectar con Binance. Revisa tu conexión a internet.');
    }
  }

  static Future<double?> getCurrentP2PRate({
    required String fiatCurrency,
  }) async {
    const endpoint = '/bapi/c2c/v2/friendly/c2c/adv/search';
    final url = Uri.parse('$_p2pUrl$endpoint');

    print('[Binance P2P] Buscando tasa de cambio para USDT/$fiatCurrency...');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "proMerchantAds": false,
          "page": 1,
          "rows": 5,
          "payTypes": [],
          "countries": [],
          "tradeType": "BUY",
          "asset": "USDT",
          "fiat": fiatCurrency,
          "publisherType": null
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          final ads = data['data'] as List;
          
          double totalPrice = 0;
          for (var ad in ads) {
            totalPrice += double.parse(ad['adv']['price']);
          }
          final averagePrice = totalPrice / ads.length;
          
          print('[Binance P2P] Tasa promedio encontrada: $averagePrice $fiatCurrency/USDT');
          return averagePrice;
        } else {
          print('[Binance P2P] No se encontraron anuncios para el par USDT/$fiatCurrency.');
          return null;
        }
      } else {
        print('[Binance P2P] Error de la API: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('[Binance P2P] Fallo en la conexión: $e');
      return null;
    }
  }


  static String _generateSignature(String params, String secretKey) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(params);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return hex.encode(digest.bytes);
  }
}