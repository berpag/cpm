// lib/data/services/exchange_rate_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/services/binance_api_service.dart';

class ExchangeRateService {
  
  static const String _coinbaseUrl = 'https://api.coinbase.com/v2';

  /// Obtiene la tasa de cambio para un par de divisas.
  /// Para fechas actuales, intenta obtenerla automáticamente.
  /// Para fechas históricas, devuelve null para activar el modo manual.
  static Future<double?> getExchangeRate({
    required DateTime date,
    required String fromCurrency, // Siempre será 'USD'
    required String toCurrency,
  }) async { 
    if (fromCurrency.toUpperCase() == toCurrency.toUpperCase()) {
      return 1.0;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestedDay = DateTime(date.year, date.month, date.day);

    // Solo intentamos el cálculo automático si la fecha es hoy o futura.
    if (requestedDay.isAtSameMomentAs(today) || requestedDay.isAfter(today)) {
      print('[ExchangeRateService] Fecha actual detectada. Estrategia: 1. Binance, 2. Coinbase');

      // 1. Intentar con Binance P2P
      final binanceRate = await BinanceApiService.getCurrentP2PRate(fiatCurrency: toCurrency);
      if (binanceRate != null) {
        print('[ExchangeRateService] Tasa de Binance P2P obtenida con éxito.');
        return binanceRate;
      }

      // 2. Si Binance falla, intentar con Coinbase
      print('[ExchangeRateService] Binance P2P falló. Usando Coinbase como respaldo.');
      final coinbaseRate = await _tryGetRateFromCoinbase(from: fromCurrency, to: toCurrency);
      if (coinbaseRate != null) {
        print('[ExchangeRateService] Tasa de Coinbase obtenida con éxito.');
        return coinbaseRate;
      }

      print('[ExchangeRateService] Todas las APIs automáticas para la fecha actual fallaron.');
      return null; // Si ambas fallan, se activará el modo manual.

    } else {
      // Para fechas históricas, vamos directamente al modo manual.
      print('[ExchangeRateService] Fecha histórica detectada. Se requiere entrada manual.');
      return null;
    }
  }

  // --- FUNCIÓN PRIVADA PARA COINBASE ---
  static Future<double?> _tryGetRateFromCoinbase({required String from, required String to}) async {
    final url = Uri.parse('$_coinbaseUrl/exchange-rates?currency=$from');
    print('[Coinbase] Buscando en: $url');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data']?['rates']?[to] != null) {
          final rate = double.tryParse(data['data']['rates'][to]);
          if (rate != null) {
            print('[Coinbase] Tasa encontrada: $rate');
            return rate;
          }
        }
      }
    } catch (e) {
      print('[Coinbase] Error: $e');
    }
    print('[Coinbase] No se pudo obtener la tasa.');
    return null;
  }
}