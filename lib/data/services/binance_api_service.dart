// lib/data/services/binance_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';

// --- Clases de Modelo (sin cambios) ---
class BinanceBalance {
  final String asset;
  final double free;
  final double locked;
  BinanceBalance({required this.asset, required this.free, required this.locked});
  factory BinanceBalance.fromJson(Map<String, dynamic> json) {
    return BinanceBalance(asset: json['asset'], free: double.parse(json['free']), locked: double.parse(json['locked']));
  }
}

class BinanceTrade {
  final String symbol;
  final int id;
  final int orderId;
  final double price;
  final double qty;
  final double quoteQty;
  final double commission;
  final String commissionAsset;
  final int time;
  final bool isBuyer;
  final bool isMaker;
  BinanceTrade({required this.symbol, required this.id, required this.orderId, required this.price, required this.qty, required this.quoteQty, required this.commission, required this.commissionAsset, required this.time, required this.isBuyer, required this.isMaker});
  factory BinanceTrade.fromJson(Map<String, dynamic> json) {
    return BinanceTrade(symbol: json['symbol'], id: json['id'], orderId: json['orderId'], price: double.parse(json['price']), qty: double.parse(json['qty']), quoteQty: double.parse(json['quoteQty']), commission: double.parse(json['commission']), commissionAsset: json['commissionAsset'], time: json['time'], isBuyer: json['isBuyer'], isMaker: json['isMaker']);
  }
}

// --- Clase del Servicio API (COMPLETA Y CORREGIDA) ---
class BinanceApiService {
  static const String _binanceBaseUrl = 'https://api.binance.com';
  // Usamos un proxy público. Para producción, sería ideal tener uno propio.
  static const String _corsProxyUrl = 'https://cors-anywhere.herokuapp.com/';

  // Función inteligente que decide qué URL base usar
  static String get _baseUrl {
    if (kIsWeb) {
      // Si estamos en la web, usamos el proxy
      return _corsProxyUrl + _binanceBaseUrl;
    } else {
      // Si estamos en Android, iOS, etc., vamos directo
      return _binanceBaseUrl;
    }
  }

  static Future<int> _getServerTime() async {
    const endpoint = '/api/v3/time';
    final url = Uri.parse('$_baseUrl$endpoint');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['serverTime'];
      } else {
        return DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  static Future<List<BinanceBalance>> getAccountInfo({required String apiKey, required String secretKey}) async {
    const endpoint = '/api/v3/account';
    print("\n--- [Binance API Debug] Iniciando getAccountInfo ---");
    
    try {
      final timestamp = await _getServerTime();
      final params = 'timestamp=$timestamp';
      print("[Binance API Debug] Parámetros: $params");
      
      final signature = _generateSignature(params, secretKey);
      print("[Binance API Debug] Firma Generada: $signature");
      
      final url = Uri.parse('$_baseUrl$endpoint?$params&signature=$signature');
      print("[Binance API Debug] URL Completa (con proxy si es web): $url");
      
      final headers = {'X-MBX-APIKEY': apiKey};
      print("[Binance API Debug] Headers: $headers");

      final response = await http.get(url, headers: headers);
      
      print("[Binance API Debug] Código de Estado de la Respuesta: ${response.statusCode}");
      print("[Binance API Debug] Cuerpo de la Respuesta: ${response.body}");

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        print("[Binance API Debug] Conexión exitosa. Procesando balances...");
        final List<dynamic> balancesJson = data['balances'] ?? [];
        return balancesJson.map((json) => BinanceBalance.fromJson(json)).where((b) => b.free > 0 || b.locked > 0).toList();
      } else {
        throw Exception('Error de Binance [${data['code']}]: ${data['msg']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print("[Binance API Debug] Se atrapó una excepción: $e");
      }
      throw Exception('No se pudo conectar con Binance. Revisa la consola para más detalles.');
    } finally {
        print("--- [Binance API Debug] Finalizado getAccountInfo ---\n");
    }
  }
  
  static Future<List<String>> getAllSymbols() async {
    const endpoint = '/api/v3/exchangeInfo';
    final url = Uri.parse('$_baseUrl$endpoint');
    print("[Binance API] Obteniendo todos los símbolos de trading...");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> symbolsData = data['symbols'] ?? [];
        final symbols = symbolsData
            .where((s) => s['status'] == 'TRADING')
            .map((s) => s['symbol'] as String)
            .toList();
        print("[Binance API] Se encontraron ${symbols.length} símbolos activos.");
        return symbols;
      } else {
        throw Exception('Error de Binance al obtener la información del exchange.');
      }
    } catch (e) {
      throw Exception('No se pudo obtener la lista de símbolos: $e');
    }
  }

  static Future<List<BinanceTrade>> getTradeHistory({required String apiKey, required String secretKey, required String symbol, int? startTime}) async {
    const endpoint = '/api/v3/myTrades';
    final List<BinanceTrade> allTrades = [];
    int? lastTradeId;

    while (true) {
      final timestamp = await _getServerTime();
      String params = 'symbol=$symbol&timestamp=$timestamp&limit=1000';
      if (startTime != null && lastTradeId == null) {
        params = 'startTime=$startTime&$params';
      }
      if (lastTradeId != null) {
        params = 'fromId=$lastTradeId&$params';
      }
      
      final signature = _generateSignature(params, secretKey);
      final url = Uri.parse('$_baseUrl$endpoint?$params&signature=$signature');
      
      try {
        final response = await http.get(url, headers: {'X-MBX-APIKEY': apiKey});
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (data.isEmpty) break;
          
          final trades = data.map((tradeJson) => BinanceTrade.fromJson(tradeJson)).toList();
          allTrades.addAll(trades);
          lastTradeId = trades.last.id + 1;
          
          if (trades.length < 1000) break;
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          final data = json.decode(response.body);
          if (data['msg'] != null && data['msg'].contains('Invalid symbol')) {
            break;
          }
          throw Exception('Error de Binance: ${data['msg']}');
        }
      } catch (e) {
        throw Exception('No se pudo obtener el historial de trades para $symbol: $e');
      }
    }
    allTrades.sort((a, b) => a.time.compareTo(b.time));
    return allTrades;
  }

  static String _generateSignature(String params, String secretKey) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(params);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return hex.encode(digest.bytes);
  }
}