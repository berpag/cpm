// lib/data/services/bitcoin_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class BitcoinApiService {
  // Usamos la API pública y gratuita de Blockstream.info
  static const String _baseUrl = 'https://blockstream.info/api';

  /// Obtiene el balance de BTC para una dirección.
  /// Utiliza la API de Blockstream para obtener la información de la dirección.
  static Future<Map<String, double>> getBitcoinBalance(String address) async {
    print('[Bitcoin API] Iniciando consulta de balance para: $address');
    final url = Uri.parse('$_baseUrl/address/$address');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // La respuesta contiene 'chain_stats' y 'mempool_stats' con las sumas de UTXOs
        final fundedTxoSum = data['chain_stats']['funded_txo_sum'] as int? ?? 0;
        final spentTxoSum = data['chain_stats']['spent_txo_sum'] as int? ?? 0;
        
        // El balance actual es el total recibido menos el total gastado
        final balanceInSatoshis = fundedTxoSum - spentTxoSum;
        
        // Convertimos de satoshis a BTC (1 BTC = 100,000,000 satoshis)
        final balanceInBtc = balanceInSatoshis / 100000000;
        
        print('[Bitcoin API] Balance de BTC encontrado: $balanceInBtc');
        return {'BTC': balanceInBtc};
        
      } else {
        // Si la dirección no existe o hay un error, la API devuelve un no-200
        print('[Bitcoin API] Error al obtener balance de Bitcoin: ${response.statusCode} - ${response.body}');
        throw Exception('No se pudo obtener el balance para la dirección de Bitcoin.');
      }

    } catch (e) {
      print('[Bitcoin API] Excepción al obtener balance de Bitcoin: $e');
      throw Exception('Error de red o de formato al consultar el balance de Bitcoin.');
    }
  }
}