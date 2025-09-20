// lib/data/services/binance_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto; // Renombrado para evitar colisión
import 'package:convert/convert.dart';
import 'package:cpm/data/models/coin_models.dart';

class BinanceApiService {
  static const String _baseUrl = 'https://api.binance.com';
  static const String _p2pUrl = 'https://p2p.binance.com';

  // --- getHistoricalPriceAtTime no cambia ---
  static Future<double?> getHistoricalPriceAtTime(String symbol, DateTime timestamp) async {
    // ... (código sin cambios)
  }

  // --- ¡FUNCIÓN REESCRITA CON LA LÓGICA MEJORADA! ---
  /// Obtiene los precios actuales en USDT para una lista de tickers desde la API de Binance.
  /// Implementa una estrategia robusta: obtiene todos los precios y filtra localmente.
  /// Devuelve un mapa con los tickers que encontró y su precio.
  static Future<Map<String, CryptoCoin>> getPricesFromBinance(Set<String> tickers) async {
    if (tickers.isEmpty) return {};
    
    // El endpoint para obtener todos los precios de los símbolos.
    const endpoint = '/api/v3/ticker/price';
    final url = Uri.parse('$_baseUrl$endpoint');
    
    print('[Binance API] Obteniendo TODOS los precios de mercado para filtrar...');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> allPricesData = json.decode(response.body);
        final Map<String, CryptoCoin> foundPrices = {};
        
        // Iteramos sobre todos los precios devueltos por Binance
        for (var item in allPricesData) {
          final symbol = item['symbol'] as String;
          
          // Buscamos solo los pares contra USDT
          if (symbol.endsWith('USDT')) {
            final baseTicker = symbol.replaceAll('USDT', '').toLowerCase();
            
            // Si este ticker es uno de los que estamos buscando...
            if (tickers.contains(baseTicker)) {
              foundPrices[baseTicker] = CryptoCoin(
                id: baseTicker, // Usamos el ticker como id, que es nuestro estándar
                name: '', // Binance no nos da el nombre completo aquí
                ticker: baseTicker.toUpperCase(),
                price: double.parse(item['price']),
              );
            }
          }
        }
        
        print('[Binance API] Precios encontrados: ${foundPrices.keys.map((t) => t.toUpperCase()).join(', ')}');
        return foundPrices;

      } else {
        print('[Binance API] Error al obtener la lista completa de precios: ${response.body}');
        // Si la llamada principal falla, no podemos continuar. Devolvemos un mapa vacío.
        return {};
      }
    } catch (e) {
      print('[Binance API] Excepción al obtener precios: $e');
      return {};
    }
  }

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
          "proMerchantAds": false, "page": 1, "rows": 5, "payTypes": [],
          "countries": [], "tradeType": "BUY", "asset": "USDT",
          "fiat": fiatCurrency, "publisherType": null
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
    final hmacSha256 = crypto.Hmac(crypto.sha256, key); // Usando el alias 'crypto'
    final digest = hmacSha256.convert(bytes);
    return hex.encode(digest.bytes);
  }
}