// Versión 1.3
// lib/data/services/api_service_cmc.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cpm/data/models/coin_models.dart';

class ApiServiceCmc {
  // --- ¡IMPORTANTE! REEMPLAZA ESTO CON TU PROPIA CLAVE DE API ---
  static const String _apiKey = 'TU_CLAVE_DE_API_VA_AQUI'; 
  // -----------------------------------------------------------------
  
  static const String _baseUrl = 'https://pro-api.coinmarketcap.com';

  static Future<List<CryptoCoin>> getCoins() async {
    print("[ApiServiceCmc] Intentando obtener monedas desde CoinMarketCap...");
    
    final url = '$_baseUrl/v1/cryptocurrency/listings/latest?start=1&limit=20&convert=USD';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-CMC_PRO_API_KEY': _apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print("[ApiServiceCmc] Respuesta exitosa de CoinMarketCap.");
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> coinsData = data['data'] ?? [];

        return coinsData.map((json) {
          final quote = json['quote']['USD'];
          return CryptoCoin(
            id: json['slug'], 
            name: json['name'],
            ticker: json['symbol'].toUpperCase(),
            price: (quote['price'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

      } else {
        print("[ApiServiceCmc] Error de API: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to load coins from CoinMarketCap');
      }
    } catch (e) {
      print("[ApiServiceCmc] Error de conexión: $e");
      throw Exception('Failed to connect to the network: $e');
    }
  }
}