// lib/data/services/bittensor_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class BittensorApiService {
  static const String _baseUrl = 'https://taostats.io/api';

  /// Obtiene el balance de TAO para una dirección de Bittensor (hotkey).
  static Future<Map<String, double>> getTaoBalance(String address) async {
    print('[Bittensor API] Iniciando consulta de balance para: $address');
    final balances = <String, double>{};
    final url = Uri.parse('$_baseUrl/account?hotkey=$address');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // La API de Taostats devuelve el balance directamente.
        final balance = data['balance'] as double? ?? 0.0;
        
        balances['TAO'] = balance;
        print('[Bittensor API] Balance de TAO encontrado: $balance');

      } else if (response.statusCode == 404) {
        print('[Bittensor API] La cuenta no existe. Balance es 0.');
        balances['TAO'] = 0.0;
      } else {
        throw Exception('Error al conectar con la API de Taostats: ${response.statusCode}');
      }
      return balances;
    } catch (e) {
      print('[Bittensor API] Excepción al obtener balance de TAO: $e');
      return {'TAO': 0.0};
    }
  }
}