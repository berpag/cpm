// lib/data/services/evm_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Erc20TokenBalance {
  final String contractAddress;
  final String symbol;
  final String name;
  final double amount;

  Erc20TokenBalance({
    required this.contractAddress,
    required this.symbol,
    required this.name,
    required this.amount,
  });
}

class EvmApiService {
  static final String _ankrApiKey = dotenv.env['ANKR_API_KEY'] ?? '';
  static final String _ankrApiBaseUrl = 'https://rpc.ankr.com/multichain/$_ankrApiKey';

  static final Map<String, String> _networkAnkrNames = {
    'ethereum': 'eth',
    'bsc': 'bsc',
    'arbitrum': 'arbitrum',
    'polygon': 'polygon',
    'base': 'base', 
    // 'mode': 'mode',
  };
  
  static Future<List<Erc20TokenBalance>> getAllBalances({
    required String network,
    required String address,
  }) async {
    print('[EVM API] Consultando TODOS los balances para la red $network...');
    
    if (_ankrApiKey.isEmpty) {
      print('ERROR: La API Key de Ankr no está configurada en el archivo .env');
      return [];
    }
    
    if (!_networkAnkrNames.containsKey(network)) {
      print('Red EVM no soportada por nuestro servicio: $network');
      return [];
    }
    
    final client = http.Client();
    final balances = <Erc20TokenBalance>[];

    try {
      final response = await client.post(
        Uri.parse(_ankrApiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "jsonrpc": "2.0",
          "method": "ankr_getAccountBalance",
          "params": {
            "walletAddress": address,
            "blockchain": _networkAnkrNames[network],
          },
          "id": 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('error') && data['error'] != null) {
          throw Exception('Error de la API de Ankr: ${data['error']['message']}');
        }

        final assets = data['result']['assets'] as List<dynamic>;
        print('[EVM API] Se encontraron ${assets.length} activos en la red $network.');

        for (var asset in assets) {
          final balanceString = asset['balance'] as String;
          final decimals = asset['tokenDecimals'] as int? ?? 18;
          
          double balanceValue;

          // --- ¡LÓGICA DE PARSEO CORREGIDA! ---
          if (balanceString.contains('.')) {
            // Si el string ya tiene un decimal, es el valor final.
            balanceValue = double.tryParse(balanceString) ?? 0.0;
          } else {
            // Si es un entero, lo tratamos como 'wei' y lo convertimos.
            final balanceWei = BigInt.tryParse(balanceString) ?? BigInt.zero;
            balanceValue = (balanceWei / BigInt.from(10).pow(decimals)).toDouble();
          }

          balances.add(Erc20TokenBalance(
            contractAddress: asset['contractAddress'] ?? 'native',
            symbol: asset['tokenSymbol'] as String,
            name: asset['tokenName'] as String,
            amount: balanceValue,
          ));
        }
      } else {
        throw Exception('Error al conectar con la API de Ankr: ${response.statusCode}');
      }
      return balances;
    } catch (e) {
      print('[EVM API] Excepción al obtener balances de la red $network: $e');
      return [];
    } finally {
      client.close();
    }
  }
}