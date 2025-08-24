// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/models/summary_models.dart';
import 'package:intl/intl.dart';

class ApiService {
  static const String _cgBaseUrl = 'https://api.coingecko.com/api/v3';
  // --- ¡NUEVO! Endpoint público de Binance ---
  static const String _binanceBaseUrl = 'https://api.binance.com';

  // --- FUNCIÓN 'getCoins' MEJORADA Y CON RESPALDO DE BINANCE ---
  static Future<List<CryptoCoin>> getCoins() async {
    List<CryptoCoin> masterCoinList = [];
    
    // --- PASO 1: Obtener una lista mucho más grande de CoinGecko ---
    try {
      print("[ApiService] Intentando obtener monedas desde CoinGecko...");
      // Aumentamos el límite de 20 a 250 para tener una base de datos mucho más completa
      const url = '$_cgBaseUrl/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=false';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        masterCoinList = data.map((json) {
          return CryptoCoin(
            id: json['id'],
            name: json['name'],
            ticker: json['symbol'].toUpperCase(),
            price: (json['current_price'] as num).toDouble(),
          );
        }).toList();
        print("[ApiService] Éxito con CoinGecko. Se obtuvieron ${masterCoinList.length} monedas.");
      } else {
         print("[ApiService] Error con CoinGecko: Código ${response.statusCode}");
      }
    } catch (e) {
      print("[ApiService] Excepción al llamar a CoinGecko: $e");
    }

    // --- PASO 2: Obtener la lista de precios de Binance como respaldo ---
    try {
      print("[ApiService] Intentando obtener precios de respaldo desde Binance...");
      final response = await http.get(Uri.parse('$_binanceBaseUrl/api/v3/ticker/price'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Set<String> existingTickers = masterCoinList.map((c) => c.ticker).toSet();
        
        print("[ApiService] Éxito con Binance. Procesando ${data.length} pares para encontrar monedas faltantes.");

        // --- PASO 3: Fusionar las listas ---
        for (var binanceCoin in data) {
          String symbol = binanceCoin['symbol'];
          if (symbol.endsWith('USDT')) { // Nos basamos en pares USDT para el precio en USD
            String ticker = symbol.replaceAll('USDT', '');
            
            // Si el ticker NO está en nuestra lista de CoinGecko, lo añadimos
            if (!existingTickers.contains(ticker)) {
              masterCoinList.add(CryptoCoin(
                id: ticker.toLowerCase(), // Usamos el ticker como ID único para monedas solo de Binance
                name: ticker, // Y como nombre
                ticker: ticker,
                price: double.tryParse(binanceCoin['price'].toString()) ?? 0.0,
              ));
              existingTickers.add(ticker); 
            }
          }
        }
        print("[ApiService] Fusión completa. La lista maestra ahora tiene ${masterCoinList.length} monedas.");
      } else {
        print("[ApiService] Error con Binance: Código ${response.statusCode}");
      }
    } catch (e) {
      print("[ApiService] Excepción al llamar a Binance: $e");
    }
    
    if(masterCoinList.isEmpty) {
        throw Exception('Fallo al obtener datos de CoinGecko y Binance.');
    }
    
    return masterCoinList;
  }

  // --- LAS SIGUIENTES FUNCIONES SE MANTIENEN SIN CAMBIOS ---

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
      return {'usd': 1.0, 'eur': 1.08, 'cop': 4000.0};
    }
  }

  static Future<HistoricalData> getHistoricalData(String cryptoId, String fiatCode, DateTime date) async {
    print("[ApiService] Obteniendo datos históricos combinados para $cryptoId en $fiatCode");
    final formattedDate = DateFormat('dd-MM-yyyy').format(date);
    final url = '$_cgBaseUrl/coins/$cryptoId/history?date=$formattedDate';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['market_data'] != null && data['market_data']['current_price'] != null) {
          final priceData = data['market_data']['current_price'];
          
          final priceInUSD = (priceData['usd'] as num?)?.toDouble();
          final priceInFiat = (priceData[fiatCode.toLowerCase()] as num?)?.toDouble();

          if (priceInUSD == null || priceInUSD <= 0) {
            throw Exception('No se encontró el precio histórico en USD para la criptomoneda.');
          }

          double? exchangeRate;
          if (priceInFiat != null) {
            exchangeRate = priceInFiat / priceInUSD;
          }

          print("[ApiService] Datos históricos encontrados: Precio Cripto USD: $priceInUSD, Tasa Fiat: $exchangeRate");
          return HistoricalData(cryptoPriceInUSD: priceInUSD, fiatExchangeRate: exchangeRate);

        } else {
          throw Exception('La respuesta de la API no tiene el formato esperado.');
        }
      } else {
        throw Exception('Fallo al cargar datos históricos: ${response.statusCode}');
      }
    } catch (e) {
      print("[ApiService] Error fatal obteniendo datos históricos: $e");
      rethrow;
    }
  }
}