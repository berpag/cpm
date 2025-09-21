// lib/data/services/near_api_service.dart

import 'dart:convert'; // <-- ¡IMPORT QUE FALTABA!
import 'package:http/http.dart' as http;

class NearApiService {
  // Usamos el endpoint RPC público principal de NEAR
  static const String _rpcEndpoint = 'https://rpc.mainnet.near.org';

  /// Obtiene el balance de NEAR para una cuenta.
  static Future<Map<String, double>> getNearBalance(String accountId) async {
    print('[NEAR API] Iniciando consulta de balance para: $accountId');
    final balances = <String, double>{};

    try {
      // 1. Construimos el cuerpo de la petición JSON-RPC
      final requestBody = json.encode({
        "jsonrpc": "2.0",
        "id": "dontcare",
        "method": "query",
        "params": {
          "request_type": "view_account",
          "finality": "final",
          "account_id": accountId
        }
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
        if (data.containsKey('result') && data['result'] != null) {
          final amountInYoctoNear = BigInt.parse(data['result']['amount']);
          
          // Convertimos de yoctoNEAR a NEAR (1 NEAR = 10^24 yoctoNEAR)
          final balanceInNear = amountInYoctoNear / BigInt.from(10).pow(24);
          
          balances['NEAR'] = balanceInNear.toDouble();
          print('[NEAR API] Balance de NEAR encontrado: ${balances['NEAR']}');

        } else if (data.containsKey('error') && data['error']['cause']['name'] == 'UNKNOWN_ACCOUNT') {
          // Manejamos el caso de una cuenta no encontrada
          print('[NEAR API] La cuenta no existe. Balance es 0.');
          balances['NEAR'] = 0.0;
        } else {
           throw Exception(data['error']['data'] ?? 'Error desconocido en la respuesta de la API de NEAR');
        }
      } else {
        throw Exception('Error al conectar con el nodo RPC de NEAR. Código: ${response.statusCode}');
      }

      return balances;

    } catch (e) {
      print('[NEAR API] Excepción al obtener balance de NEAR: $e');
      balances['NEAR'] = 0.0;
      return balances;
    }
  }
}