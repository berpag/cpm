// lib/data/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';
import 'package:cpm/data/services/token_encyclopedia_service.dart';

class ApiService {
  static const String _cgBaseUrl = 'https://api.coingecko.com/api/v3';

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
        logoUrl: json['image'], // <-- CAMBIO APLICADO
      )).toList();
    } else {
      throw Exception('Fallo al cargar datos del mercado desde CoinGecko');
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
          id: json['id'], 
          name: json['name'], 
          ticker: json['symbol'].toUpperCase(), 
          price: 0.0,
          logoUrl: json['large'], // <-- CAMBIO APLICADO
        )).toList();
      } else { 
        throw Exception('Failed to search coins'); 
      }
    } catch (e) { 
      throw Exception('Failed to connect to the network: $e'); 
    }
  }

  static Future<double?> getHistoricalCoinPrice({
    required String coinId,
    required DateTime date,
  }) async {
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

  static Future<List<dynamic>> getSolanaTokenList() async {
    const url = 'https://api.coingecko.com/api/v3/coins/list?include_platform=true';
    print('[ApiService] Obteniendo la lista de tokens de Solana desde CoinGecko...');
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> allCoins = json.decode(response.body);
        final solanaCoins = allCoins.where((coin) {
          final platforms = coin['platforms'] as Map<String, dynamic>;
          return platforms.containsKey('solana') && (platforms['solana'] as String).isNotEmpty;
        }).toList();
        print('[ApiService] Se encontraron ${solanaCoins.length} tokens en la red de Solana.');
        return solanaCoins;
      } else {
        throw Exception('Fallo al cargar la lista de tokens de Solana. Código: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de red al obtener la lista de tokens: $e');
    }
  }
  // --- NUEVO MÉTODO PARA TRADUCIR CONTRATOS ---

  /// Busca la información de un token en CoinGecko usando la dirección del contrato.
  /// Este es el "traductor" que usaremos cuando encontremos un token desconocido.
  // --- REEMPLAZA ESTA FUNCIÓN EN api_service.dart ---
  static Future<TokenInfo?> getTokenInfoByContractAddress(String platform, String contractAddress) async {
    const platformIdMap = {
      'ethereum': 'ethereum', 'bsc': 'binance-smart-chain',
      'polygon': 'polygon-pos', 'arbitrum': 'arbitrum-one',
      'solana': 'solana', 'base': 'base',
    };
    final platformId = platformIdMap[platform.toLowerCase()];
    if (platformId == null) return null;

    final url = '$_cgBaseUrl/coins/$platformId/contract/$contractAddress';
    print('[ApiService] Traduciendo contrato: $url');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TokenInfo(
          id: data['id'], name: data['name'],
          symbol: (data['symbol'] as String).toUpperCase(),
          logoUrl: data['image']?['large'],
          platforms: { platform: data['contract_address'], },
        );
      } else if (response.statusCode == 429) {
        print('[ApiService] ¡LÍMITE DE TASA ALCANZADO! Se detendrán las consultas.');
        // Devolvemos un TokenInfo especial para señalar que debemos parar.
        return TokenInfo(id: 'RATE_LIMIT_EXCEEDED', name: '', symbol: '');
      } else {
        print('[ApiService] Error al traducir contrato ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('[ApiService] Excepción al traducir contrato: $e');
      return null;
    }
  }


}