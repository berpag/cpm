// lib/data/services/solana_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SolanaApiService {
  static const String _rpcEndpoint = 'https://api.mainnet-beta.solana.com';
  static const double _lamportsPerSol = 1000000000.0;

  static Future<Map<String, double>> getTokenBalances(String address) async {
    print('[Solana API V-FINAL] Iniciando consulta de balances para: $address');
    final balances = <String, double>{};
    try {
      final client = http.Client();
      final headers = {'Content-Type': 'application/json'};

      // --- OBTENER BALANCE DE SOL ---
      final solBalanceBody = json.encode({"jsonrpc":"2.0", "id":1, "method":"getBalance", "params":[address]});
      final solResponse = await client.post(Uri.parse(_rpcEndpoint), headers: headers, body: solBalanceBody);
      if (solResponse.statusCode == 200) {
        final solData = json.decode(solResponse.body);
        final lamports = solData['result']['value'] as int;
        if (lamports > 0) balances['SOL'] = lamports / _lamportsPerSol;
      }

      // --- OBTENER BALANCES DE TOKENS SPL ---
      final requestBody = json.encode({
        "jsonrpc": "2.0", "id": 1, "method": "getTokenAccountsByOwner",
        "params": [
          address,
          {"programId": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"},
          {"encoding": "jsonParsed"}
        ]
      });
      final response = await client.post(Uri.parse(_rpcEndpoint), headers: headers, body: requestBody);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accounts = data['result']['value'] as List<dynamic>;
        print('[Solana API V-FINAL] Se encontraron ${accounts.length} cuentas de tokens SPL.');
        for (final account in accounts) {
          final info = account['account']['data']['parsed']['info'];
          final tokenAmount = info['tokenAmount'];
          final amount = double.tryParse(tokenAmount['uiAmountString'] ?? '0.0') ?? 0.0;
          final mint = info['mint'] as String;
          if (amount > 1e-9) {
            balances.update(mint, (value) => value + amount, ifAbsent: () => amount);
          }
        }
      }
      client.close();
      return balances;
    } catch (e) {
      print('[Solana API V-FINAL] Error CRÍTICO: $e');
      return balances;
    }
  }
}