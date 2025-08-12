// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';
// ¡Importante! Necesitamos 'intl' aquí también para formatear la fecha para la API.
import 'package:intl/intl.dart';

class ApiService {
  static const String _baseUrl = 'https://api.coingecko.com/api/v3';

  // ... (getCoins y searchCoins no cambian)
  static Future<List<CryptoCoin>> getCoins() async { /* ... */ 
    final url = '$_baseUrl/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=20&page=1&sparkline=false';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => CryptoCoin(id: json['id'], name: json['name'], ticker: json['symbol'].toUpperCase(), price: (json['current_price'] as num).toDouble())).toList();
      } else { throw Exception('Failed to load market coins'); }
    } catch (e) { throw Exception('Failed to connect to the network: $e'); }
  }
  static Future<List<CryptoCoin>> searchCoins(String query) async { /* ... */ 
    if (query.isEmpty) return [];
    final url = '$_baseUrl/search?query=$query';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> coinsData = data['coins'] ?? [];
        return coinsData.map((json) => CryptoCoin(id: json['id'], name: json['name'], ticker: json['symbol'].toUpperCase(), price: 0.0)).toList();
      } else { throw Exception('Failed to search coins'); }
    } catch (e) { throw Exception('Failed to connect to the network: $e'); }
  }
  static Future<CryptoCoin> getCoinDetails(String coinId) async { /* ... */ 
    final url = '$_baseUrl/coins/markets?vs_currency=usd&ids=$coinId&sparkline=false';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final json = data.first;
          return CryptoCoin(id: json['id'], name: json['name'], ticker: json['symbol'].toUpperCase(), price: (json['current_price'] as num).toDouble());
        } else { throw Exception('Coin not found'); }
      } else { throw Exception('Failed to load coin details'); }
    } catch (e) { throw Exception('Failed to connect to the network: $e'); }
  }

  // --- ¡NUEVA FUNCIÓN PARA OBTENER EL PRECIO HISTÓRICO! ---
  static Future<double> getHistoricalPrice(String coinId, DateTime date) async {
    // La API de CoinGecko requiere la fecha en formato dd-mm-yyyy.
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    final url = '$_baseUrl/coins/$coinId/history?date=$formattedDate';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // La estructura de la respuesta es anidada. Navegamos hasta el precio.
        if (data['market_data'] != null && data['market_data']['current_price'] != null) {
          final priceData = data['market_data']['current_price'];
          // Devolvemos el precio en USD. Si no existe, devolvemos 0.0.
          return (priceData['usd'] as num?)?.toDouble() ?? 0.0;
        } else {
          return 0.0; // La API no tenía datos para esa fecha.
        }
      } else {
        throw Exception('Failed to load historical price');
      }
    } catch (e) {
      throw Exception('Failed to connect to the network: $e');
    }
  }
}