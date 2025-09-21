// lib/data/services/cardano_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CardanoApiService {
  static final String _apiKey = dotenv.env['BLOCKFROST_API_KEY'] ?? '';
  static const String _baseUrl = 'https://cardano-mainnet.blockfrost.io/api/v0';

  /// Obtiene el balance de ADA para una dirección de Cardano.
  static Future<Map<String, double>> getAdaBalance(String address) async {
    print('[Cardano API] Iniciando consulta de balance para: $address');
    if (_apiKey.isEmpty) {
      print('ERROR: La API Key de Blockfrost no está configurada en el archivo .env');
      return {};
    }

    final balances = <String, double>{};
    final url = Uri.parse('$_baseUrl/accounts/$address');

    try {
      final response = await http.get(
        url,
        headers: {'project_id': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final controlledAmount = data['controlled_amount'] as List<dynamic>;
        
        final adaData = controlledAmount.firstWhere(
          (asset) => asset['unit'] == 'lovelace',
          orElse: () => null,
        );

        if (adaData != null) {
          final balanceInLovelace = BigInt.parse(adaData['quantity']);
          // 1 ADA = 1,000,000 lovelace
          final balanceInAda = balanceInLovelace / BigInt.from(1000000);
          balances['ADA'] = balanceInAda.toDouble();
          print('[Cardano API] Balance de ADA encontrado: ${balances['ADA']}');
        } else {
          balances['ADA'] = 0.0;
        }
      } else if (response.statusCode == 404) {
        print('[Cardano API] La cuenta no existe. Balance es 0.');
        balances['ADA'] = 0.0;
      } else {
        throw Exception('Error al conectar con la API de Blockfrost: ${response.statusCode}');
      }
      return balances;
    } catch (e) {
      print('[Cardano API] Excepción al obtener balance de ADA: $e');
      return {'ADA': 0.0};
    }
  }
}