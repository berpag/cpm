// lib/data/services/hedera_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class HederaApiService {
  // Usamos la API del mirror node principal de Hedera
  static const String _baseUrl = 'https://mainnet-public.mirrornode.hedera.com';

  /// Obtiene el balance de HBAR para una cuenta de Hedera.
  static Future<Map<String, double>> getHbarBalance(String accountId) async {
    print('[Hedera API] Iniciando consulta de balance para: $accountId');
    final balances = <String, double>{};
    
    // El formato de la cuenta puede ser 0.0.12345
    final url = Uri.parse('$_baseUrl/api/v1/accounts/$accountId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // La respuesta contiene una lista de balances. Buscamos el de HBAR.
        final balancesList = data['balance']['balances'] as List<dynamic>;
        
        // Para HBAR, la lista de balances está vacía, y el balance principal está en otro campo.
        final balanceInTinybars = data['balance']['balance'] as int? ?? 0;
        
        // Convertimos de tinybars a HBAR (1 HBAR = 100,000,000 tinybars)
        final balanceInHbar = balanceInTinybars / 100000000;
        
        balances['HBAR'] = balanceInHbar;
        print('[Hedera API] Balance de HBAR encontrado: $balanceInHbar');

      } else if (response.statusCode == 404) {
        print('[Hedera API] La cuenta no existe. Balance es 0.');
        balances['HBAR'] = 0.0;
      }
      else {
        throw Exception('Error al conectar con la API de Hedera: ${response.statusCode}');
      }

      return balances;

    } catch (e) {
      print('[Hedera API] Excepción al obtener balance de HBAR: $e');
      balances['HBAR'] = 0.0;
      return balances;
    }
  }
}