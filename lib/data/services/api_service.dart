// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';

class ApiService {
  static const String _cgBaseUrl = 'https://api.coingecko.com/api/v3';

  static Future<List<CryptoCoin>> getCoins() async {
    print("[ApiService] Intentando obtener monedas desde CoinGecko...");
    final url = '$_cgBaseUrl/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=20&page=1&sparkline=false';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print("[ApiService] Éxito con CoinGecko.");
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => CryptoCoin(
              id: json['id'],
              name: json['name'],
              ticker: json['symbol'].toUpperCase(),
              price: (json['current_price'] as num).toDouble(),
            )).toList();
      } else {
        throw Exception('CoinGecko API error: ${response.statusCode}');
      }
    } catch (e) {
      print("[ApiService] FALLO con CoinGecko: $e.");
      throw Exception('Fallo al obtener datos de CoinGecko.');
    }
  }

  static Future<List<CryptoCoin>> searchCoins(String query) async {
    if (query.isEmpty) return [];
    final url = '$_cgBaseUrl/search?query=$query';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> coinsData = data['coins'] ?? [];
        return coinsData.map((json) => CryptoCoin(
          id: json['id'], name: json['name'], ticker: json['symbol'].toUpperCase(), price: 0.0,
        )).toList();
      } else { throw Exception('Failed to search coins'); }
    } catch (e) { throw Exception('Failed to connect to the network: $e'); }
  }

  static Future<CryptoCoin> getCoinDetails(String coinId) async {
    final url = '$_cgBaseUrl/coins/markets?vs_currency=usd&ids=$coinId&sparkline=false';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final json = data.first;
          return CryptoCoin(
            id: json['id'], name: json['name'], ticker: json['symbol'].toUpperCase(),
            price: (json['current_price'] as num).toDouble(),
          );
        } else { throw Exception('Coin not found'); }
      } else { throw Exception('Failed to load coin details'); }
    } catch (e) { throw Exception('Failed to connect to the network: $e'); }
  }

  static Future<double> getHistoricalPrice(String coinId, DateTime date) async {
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    final url = '$_cgBaseUrl/coins/$coinId/history?date=$formattedDate';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['market_data'] != null && data['market_data']['current_price'] != null) {
          final priceData = data['market_data']['current_price'];
          return (priceData['usd'] as num?)?.toDouble() ?? 0.0;
        } else { return 0.0; }
      } else { throw Exception('Failed to load historical price'); }
    } catch (e) { throw Exception('Failed to connect to the network: $e'); }
  }
  
  static Future<Map<String, double>> getFiatExchangeRates() async {
    print("[ApiService] Obteniendo tasas de cambio Fiat...");
    const url = 'https://api.coingecko.com/api/v3/exchange_rates';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final rates = data['rates'];
        
        final double btcPerUsd = (rates['usd']['value'] as num).toDouble();
        final Map<String, double> exchangeRates = {};
        
        // Iteramos sobre todas las tasas para calcular su valor en relación a 1 USD
        rates.forEach((key, value) {
          final rateValue = (value['value'] as num).toDouble();
          exchangeRates[key] = rateValue / btcPerUsd;
        });
        
        return exchangeRates;
      } else {
        throw Exception('Failed to load exchange rates');
      }
    } catch (e) {
      print("[ApiService] Error obteniendo tasas de cambio: $e");
      return {'usd': 1.0, 'eur': 1.08, 'cop': 4000.0}; // Valores de fallback
    }
  }

  // --- NUEVA FUNCIÓN PARA TASAS DE CAMBIO HISTÓRICAS ---
  static Future<double> getHistoricalFiatExchangeRate(String fiatCode, DateTime date) async {
    if (fiatCode.toLowerCase() == 'usd') {
      return 1.0;
    }

    print("[ApiService] Obteniendo tasa de cambio histórica para $fiatCode en la fecha ${date.toIso8601String()}");

    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    final url = '$_cgBaseUrl/coins/bitcoin/history?date=$formattedDate';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['market_data'] != null && data['market_data']['current_price'] != null) {
          final priceData = data['market_data']['current_price'];
          
          final priceInUSD = (priceData['usd'] as num?)?.toDouble();
          final priceInFiat = (priceData[fiatCode.toLowerCase()] as num?)?.toDouble();

          if (priceInUSD != null && priceInFiat != null && priceInUSD > 0) {
            final exchangeRate = priceInFiat / priceInUSD;
            print("[ApiService] Tasa histórica encontrada: 1 USD = $exchangeRate ${fiatCode.toUpperCase()}");
            return exchangeRate;
          } else {
            print("[ApiService] ADVERTENCIA: No se encontraron datos de precio para USD o ${fiatCode.toUpperCase()} en la respuesta.");
            throw Exception('Datos de precio no disponibles para la conversión.');
          }
        } else {
          throw Exception('La respuesta de la API no tiene el formato esperado.');
        }
      } else {
        throw Exception('Fallo al cargar la tasa de cambio histórica: ${response.statusCode}');
      }
    } catch (e) {
      print("[ApiService] Error fatal obteniendo tasa histórica: $e");
      throw Exception('No se pudo obtener la tasa de cambio histórica.');
    }
  }
}