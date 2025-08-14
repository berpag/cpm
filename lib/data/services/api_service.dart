// Versión 1.3 - Estable (Respaldo Desactivado)
// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';

class ApiService {
  static const String _cgBaseUrl = 'https://api.coingecko.com/api/v3';

  static Future<List<CryptoCoin>> getCoins() async {
    print("[ApiService] Intentando obtener monedas desde CoinGecko...");
    // Asegurándonos de que la URL esté correcta
    final url = '$_cgBaseUrl/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=20&page=1&sparkline=false';
    
    try {
      // INTENTO 1: Usar CoinGecko.
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
      
      // --- LÓGICA DE RESPALDO DESACTIVADA TEMPORALMENTE POR CORS ---
      // En el futuro, esta sección se activará cuando tengamos un backend.
      /*
      print("[ApiService] Intentando con el respaldo de CoinMarketCap...");
      try {
        final cmcCoins = await ApiServiceCmc.getCoins();
        print("[ApiService] Éxito con el respaldo de CoinMarketCap.");
        return cmcCoins;
      } catch (cmcError) {
        print("[ApiService] FALLO con el respaldo de CoinMarketCap: $cmcError");
        throw Exception('Ambos proveedores de API fallaron.');
      }
      */

      // Por ahora, si CoinGecko falla, simplemente lanzamos el error final.
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
}