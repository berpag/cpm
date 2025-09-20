// lib/data/services/price_service.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart'; // Aún lo necesitamos para el fallback a CoinGecko
import 'package:cpm/data/services/binance_api_service.dart';

class PriceService {

  /// Obtiene los precios de mercado actuales para una lista de IDs de moneda.
  /// Sigue una estrategia híbrida: primero intenta con la API de Binance por su rapidez
  /// y luego recurre a la API de CoinGecko para las monedas no encontradas.
  ///
  /// [coinIds]: Una lista de los IDs de las monedas a consultar (ej. ['bitcoin', 'ethereum']).
  ///
  /// Devuelve un `Future` que se resuelve en una `List<CryptoCoin>` con los precios encontrados.
  static Future<List<CryptoCoin>> getMarketPricesForIds(List<String> coinIds) async {
    if (coinIds.isEmpty) return [];

    print('[PriceService] Iniciando obtención de precios para: $coinIds');
    
    final List<CryptoCoin> finalPriceList = [];
    
    // Usamos un mapa para poder volver de ticker a coinId si es necesario.
    final Map<String, String> tickerToCoinIdMap = {};
    for (var id in coinIds) {
      // Nuestro estándar es que el ID es el ticker en minúsculas.
      tickerToCoinIdMap[id.toLowerCase()] = id;
    }
    final tickersToQuery = tickerToCoinIdMap.keys.toSet();

    // 1. PRIMER INTENTO: OBTENER PRECIOS DE BINANCE
    // Usamos un try-catch para que un error en Binance no detenga el proceso.
    try {
      final binancePrices = await BinanceApiService.getPricesFromBinance(tickersToQuery);
      finalPriceList.addAll(binancePrices.values);
    } catch (e) {
      print('[PriceService] Ocurrió un error al consultar Binance: $e');
    }

    // 2. IDENTIFICAR MONEDAS FALTANTES
    final foundTickers = finalPriceList.map((c) => c.ticker.toLowerCase()).toSet();
    final missingTickers = tickersToQuery.difference(foundTickers);

    // 3. SEGUNDO INTENTO: OBTENER PRECIOS FALTANTES DE COINGECKO
    if (missingTickers.isNotEmpty) {
      print('[PriceService] Faltan precios para: $missingTickers. Consultando CoinGecko...');
      // Convertimos los tickers faltantes de nuevo a los IDs originales de CoinGecko.
      final missingCoinIds = missingTickers.map((ticker) => tickerToCoinIdMap[ticker]!).toList();
      
      try {
        // Usaremos el método privado de CoinGecko que estará en ApiService
        final coingeckoPrices = await ApiService.getPricesFromCoinGecko(missingCoinIds);
        finalPriceList.addAll(coingeckoPrices);
      } catch (e) {
        print('[PriceService] Error al obtener precios de CoinGecko como respaldo: $e');
      }
    }
    
    // Aseguramos que las stablecoins tengan un precio de 1.0 si alguna API falla.
    _handleStablecoins(finalPriceList, coinIds);

    print('[PriceService] Obtención de precios finalizada. Total encontrados: ${finalPriceList.length}');
    return finalPriceList;
  }

  // --- Función auxiliar para stablecoins ---
  // Esta lógica es idéntica a la que ya teníamos.
  static void _handleStablecoins(List<CryptoCoin> priceList, List<String> requestedIds) {
      if (requestedIds.contains('tether') && !priceList.any((c) => c.id == 'tether')) {
        priceList.add(CryptoCoin(id: 'tether', name: 'Tether', ticker: 'USDT', price: 1.0));
      }
      if (requestedIds.contains('usd-coin') && !priceList.any((c) => c.id == 'usd-coin')) {
        priceList.add(CryptoCoin(id: 'usd-coin', name: 'USD Coin', ticker: 'USDC', price: 1.0));
      }
      // Podríamos añadir más stablecoins aquí si fuera necesario (BUSD, FDUSD, etc.)
  }
}