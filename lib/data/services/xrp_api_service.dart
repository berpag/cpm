// lib/data/services/xrp_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class XrpApiService {
  // Usamos el cliente RPC público proporcionado por xrpl.org
  static const String _rpcEndpoint = 'https://s2.ripple.com:51234/';

  static Future<Map<String, double>> getXrpBalance(String address) async {
    print('[XRP API] Iniciando consulta de balance para: $address');
    final balances = <String, double>{};
    
    try {
      // 1. Construimos el cuerpo de la petición JSON-RPC a mano
      final requestBody = json.encode({
        "method": "account_info",
        "params": [
          {
            "account": address,
            "strict": true,
            "ledger_index": "validated"
          }
        ]
      });

      // 2. Hacemos la llamada HTTP POST
      final response = await http.post(
        Uri.parse(_rpcEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 3. Parseamos la respuesta
        if (data['result'] != null && data['result']['status'] == 'success') {
          if (data['result']['account_data'] != null) {
            final balanceInDrops = BigInt.parse(data['result']['account_data']['Balance']);
            final balanceInXrp = balanceInDrops / BigInt.from(1000000);
            
            balances['XRP'] = balanceInXrp.toDouble();
            print('[XRP API] Balance de XRP encontrado: ${balances['XRP']}');
          } else if (data['result']['error'] == 'actNotFound') {
            // Manejamos el caso de una cuenta no encontrada
            print('[XRP API] La cuenta no ha sido activada en la red. Balance es 0.');
            balances['XRP'] = 0.0;
          }
        } else {
          throw Exception(data['result']['error_message'] ?? 'Error desconocido en la respuesta de la API de XRP');
        }
      } else {
        throw Exception('Error al conectar con el nodo RPC de XRP. Código: ${response.statusCode}');
      }

      return balances;

    } catch (e) {
      print('[XRP API] Excepción al obtener balance de XRP: $e');
      // Si hay cualquier error, devolvemos 0 para no detener la sincronización.
      balances['XRP'] = 0.0;
      return balances;
    }
  }
}