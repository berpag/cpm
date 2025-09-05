// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';

class ApiService {
  static const String _cgBaseUrl = 'https://api.coingecko.com/api/v3';

  // --- FUNCIÓN PRINCIPAL PARA PRECIOS ---
  static Future<List<CryptoCoin>> getMarketDataForIds(List<String> coinIds) async {
    if (coinIds.isEmpty) return [];

    final cryptoIds = coinIds.where((id) => id != 'colombian-peso').toList();
    if (cryptoIds.isEmpty) return [];

    final idsString = cryptoIds.join(',');
    final url = '$_cgBaseUrl/coins/markets?vs_currency=usd&ids=$idsString&sparkline=false';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final coins = data.map((json) => CryptoCoin(
          id: json['id'],
          name: json['name'],
          ticker: json['symbol'].toUpperCase(),
          price: (json['current_price'] as num? ?? 0.0).toDouble(),
        )).toList();

        if (coinIds.contains('tether') && !coins.any((c) => c.id == 'tether')) {
          coins.add(CryptoCoin(id: 'tether', name: 'Tether', ticker: 'USDT', price: 1.0));
        }
        if (coinIds.contains('usd-coin') && !coins.any((c) => c.id == 'usd-coin')) {
          coins.add(CryptoCoin(id: 'usd-coin', name: 'USD Coin', ticker: 'USDC', price: 1.0));
        }
        return coins;

      } else {
        throw Exception('Fallo al cargar datos del mercado desde CoinGecko');
      }
    } catch (e) {
      throw Exception('Error de red al obtener datos del mercado: $e');
    }
  }

  // Se usa en los diálogos de entrada manual
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
}