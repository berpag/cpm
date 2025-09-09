// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart'; // <-- ¡IMPORT AÑADIDO! Necesario para formatear la fecha.

class ApiService {
  static const String _cgBaseUrl = 'https://api.coingecko.com/api/v3';

  // --- ESTA FUNCIÓN NO CAMBIA ---
  static Future<List<CryptoCoin>> getMarketDataForIds(List<String> coinIds) async {
    if (coinIds.isEmpty) return [];

    // Filtramos para no incluir monedas fiat en la llamada a la API de cripto
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

        // Manejo de stablecoins para asegurar que siempre tengan precio de 1.0
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

  // --- ESTA FUNCIÓN NO CAMBIA ---
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

  // --- ¡NUEVA FUNCIÓN AÑADIDA! ---
  /// Obtiene el precio en USD de una criptomoneda específica en una fecha histórica.
  ///
  /// [coinId]: El ID de la moneda en CoinGecko (ej. "bitcoin").
  /// [date]: La fecha para la cual se solicita el precio.
  ///
  /// Devuelve un [double] con el precio en USD, o [null] si ocurre un error o no se encuentran datos.
  static Future<double?> getHistoricalCoinPrice({
    required String coinId,
    required DateTime date,
  }) async {
    // La API de CoinGecko requiere la fecha en formato dd-MM-yyyy.
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    final url = '$_cgBaseUrl/coins/$coinId/history?date=$formattedDate&localization=false';

    print('[ApiService] Buscando precio histórico para $coinId en la fecha $formattedDate...');
    print('[ApiService] URL de la petición: $url');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // La estructura de la respuesta es: { "market_data": { "current_price": { "usd": 69000.123 } } }
        // Hacemos una validación segura para evitar errores si la estructura cambia o no hay datos.
        if (data['market_data'] != null &&
            data['market_data']['current_price'] != null &&
            data['market_data']['current_price']['usd'] != null) {
              
          final price = (data['market_data']['current_price']['usd'] as num).toDouble();
          print('[ApiService] Precio histórico encontrado: $price USD');
          return price;

        } else {
          print('[ApiService] La respuesta de la API no contiene el precio en USD para la fecha solicitada.');
          return null; // No se encontró el precio en la respuesta.
        }
      } else {
        print('[ApiService] Error de la API de historial: ${response.statusCode} - ${response.body}');
        return null; // La API devolvió un error (ej. 404 si no hay datos).
      }
    } catch (e) {
      print('[ApiService] Error de conexión o de formato en historial: $e');
      return null; // Error de red o al procesar la respuesta.
    }
  }
}