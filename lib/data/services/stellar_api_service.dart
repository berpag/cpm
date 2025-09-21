// lib/data/services/stellar_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class StellarApiService {
  // Usamos el servidor público de Horizon proporcionado por la Stellar Development Foundation
  static const String _horizonUrl = 'https://horizon.stellar.org';

  /// Obtiene el balance de XLM para una dirección de Stellar.
  static Future<Map<String, double>> getXlmBalance(String address) async {
    print('[Stellar API] Iniciando consulta de balance para: $address');
    final balances = <String, double>{};
    
    // Las direcciones de Stellar son sensibles a mayúsculas/minúsculas, no las modificamos.
    final url = Uri.parse('$_horizonUrl/accounts/$address');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // La respuesta contiene una lista de 'balances'. Buscamos el de XLM.
        final balancesList = data['balances'] as List<dynamic>;
        
        // Buscamos el balance que corresponde a la moneda nativa (XLM)
        final xlmBalanceData = balancesList.firstWhere(
          (balance) => balance['asset_type'] == 'native',
          orElse: () => null, // Devolvemos null si no se encuentra
        );

        if (xlmBalanceData != null) {
          final balanceString = xlmBalanceData['balance'] as String;
          final balance = double.tryParse(balanceString) ?? 0.0;
          
          balances['XLM'] = balance;
          print('[Stellar API] Balance de XLM encontrado: $balance');
        } else {
          // Si la cuenta existe pero no tiene balance de XLM (muy raro), asignamos 0.
          balances['XLM'] = 0.0;
        }

      } else if (response.statusCode == 404) {
        // El código 404 significa que la cuenta no existe en la red (no ha sido activada).
        print('[Stellar API] La cuenta no ha sido activada en la red. Balance es 0.');
        balances['XLM'] = 0.0;
      }
      else {
        throw Exception('Error al conectar con la API de Horizon: ${response.statusCode}');
      }

      return balances;

    } catch (e) {
      print('[Stellar API] Excepción al obtener balance de XLM: $e');
      // Si hay cualquier error, devolvemos 0 para no detener la sincronización.
      balances['XLM'] = 0.0;
      return balances;
    }
  }
}