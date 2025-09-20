// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';

class ApiService {
  static const String _cgBaseUrl = 'https://api.coingecko.com/api/v3';

  // --- ¡FUNCIÓN ORIGINAL ELIMINADA! La lógica ahora está en PriceService ---
  // static Future<List<CryptoCoin>> getMarketDataForIds(List<String> coinIds) async { ... }

  // --- Esta función se vuelve PÚBLICA para que PriceService pueda usarla ---
  static Future<List<CryptoCoin>> getPricesFromCoinGecko(List<String> coinIds) async {
    if (coinIds.isEmpty) return [];
    
    final idsString = coinIds.join(',');
    final url = '$_cgBaseUrl/coins/markets?vs_currency=usd&ids=$idsString&sparkline=false';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => CryptoCoin(
        id: json['id'],
        name: json['name'],
        ticker: json['symbol'].toUpperCase(),
        price: (json['current_price'] as num? ?? 0.0).toDouble(),
      )).toList();
    } else {
      throw Exception('Fallo al cargar datos del mercado desde CoinGecko');
    }
  }

  // --- La función de búsqueda no cambia ---
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
      } else { 
        throw Exception('Failed to search coins'); 
      }
    } catch (e) { 
      throw Exception('Failed to connect to the network: $e'); 
    }
  }

  // --- La función de precio histórico no cambia ---
  static Future<double?> getHistoricalCoinPrice({
    required String coinId,
    required DateTime date,
  }) async {
    // La API de CoinGecko requiere la fecha en formato dd-MM-yyyy.
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    final url = '$_cgBaseUrl/coins/$coinId/history?date=$formattedDate&localization=false';

    print('[ApiService] Buscando precio histórico para $coinId en la fecha $formattedDate...');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['market_data'] != null &&
            data['market_data']['current_price'] != null &&
            data['market_data']['current_price']['usd'] != null) {
              
          final price = (data['market_data']['current_price']['usd'] as num).toDouble();
          print('[ApiService] Precio histórico encontrado: $price USD');
          return price;
        } else {
          print('[ApiService] La respuesta de la API no contiene el precio en USD para la fecha solicitada.');
          return null;
        }
      } else {
        print('[ApiService] Error de la API de historial: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('[ApiService] Error de conexión o de formato en historial: $e');
      return null;
    }
  }
}