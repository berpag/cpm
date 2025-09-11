// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';
// --- ¡NUEVO IMPORT! ---
import 'package:cpm/data/services/binance_api_service.dart';

class ApiService {
  static const String _cgBaseUrl = 'https://api.coingecko.com/api/v3';

  // --- ¡FUNCIÓN REESCRITA COMO ORQUESTADOR HÍBRIDO! ---
  static Future<List<CryptoCoin>> getMarketDataForIds(List<String> coinIds) async {
    if (coinIds.isEmpty) return [];

    print('[ApiService Orchestrator] Iniciando obtención de precios para: $coinIds');
    
    // Lista final que contendrá todos los precios encontrados.
    final List<CryptoCoin> finalPriceList = [];
    
    // Convertimos los IDs a un Set de tickers para la consulta de Binance.
    // Usamos un mapa para poder volver de ticker a coinId si es necesario.
    final Map<String, String> tickerToCoinIdMap = {};
    for (var id in coinIds) {
      // Asumimos que el ID es el ticker en minúsculas, lo cual es nuestro estándar.
      tickerToCoinIdMap[id.toLowerCase()] = id;
    }
    final tickersToQuery = tickerToCoinIdMap.keys.toSet();

    // 1. PRIMER INTENTO: OBTENER PRECIOS DE BINANCE
    final binancePrices = await BinanceApiService.getPricesFromBinance(tickersToQuery);
    finalPriceList.addAll(binancePrices.values);

    // 2. IDENTIFICAR MONEDAS FALTANTES
    final foundTickers = binancePrices.keys.toSet();
    final missingTickers = tickersToQuery.difference(foundTickers);

    // 3. SEGUNDO INTENTO: OBTENER PRECIOS FALTANTES DE COINGECKO
    if (missingTickers.isNotEmpty) {
      print('[ApiService Orchestrator] Binance no encontró precios para: $missingTickers. Consultando CoinGecko...');
      // Convertimos los tickers faltantes de nuevo a los IDs originales de CoinGecko.
      final missingCoinIds = missingTickers.map((ticker) => tickerToCoinIdMap[ticker]!).toList();
      
      try {
        final coingeckoPrices = await _getPricesFromCoinGecko(missingCoinIds);
        finalPriceList.addAll(coingeckoPrices);
      } catch (e) {
        print('[ApiService Orchestrator] Error al obtener precios de CoinGecko como respaldo: $e');
      }
    }
    
    // Aseguramos que las stablecoins tengan un precio de 1.0 si alguna API falla
    _handleStablecoins(finalPriceList, coinIds);

    print('[ApiService Orchestrator] Obtención de precios finalizada. Total de precios encontrados: ${finalPriceList.length}');
    return finalPriceList;
  }

  // --- Función auxiliar privada para la lógica de CoinGecko ---
  static Future<List<CryptoCoin>> _getPricesFromCoinGecko(List<String> coinIds) async {
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

  // --- Función auxiliar para stablecoins ---
  static void _handleStablecoins(List<CryptoCoin> priceList, List<String> requestedIds) {
      if (requestedIds.contains('tether') && !priceList.any((c) => c.id == 'tether')) {
        priceList.add(CryptoCoin(id: 'tether', name: 'Tether', ticker: 'USDT', price: 1.0));
      }
      if (requestedIds.contains('usd-coin') && !priceList.any((c) => c.id == 'usd-coin')) {
        priceList.add(CryptoCoin(id: 'usd-coin', name: 'USD Coin', ticker: 'USDC', price: 1.0));
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