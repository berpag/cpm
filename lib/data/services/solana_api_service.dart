// lib/data/services/solana_api_service.dart

import 'package:solana/solana.dart';
import 'package:solana/dto.dart';

class SolanaApiService {
  static const String _rpcEndpoint = 'https://api.mainnet-beta.solana.com';
  
  static Future<Map<String, double>> getTokenBalances(String address) async {
    print('[Solana API] Iniciando consulta de balances para: $address');
    final balances = <String, double>{};
    
    try {
      final client = RpcClient(_rpcEndpoint);
      final owner = Ed25519HDPublicKey.fromBase58(address);

      // --- 1. OBTENER EL BALANCE DE SOL (LA MONEDA NATIVA) ---
      final solBalanceResult = await client.getBalance(owner.toBase58());
      final solBalance = solBalanceResult.value / lamportsPerSol;
      balances['SOL'] = solBalance;
      print('[Solana API] Balance de SOL encontrado: $solBalance');

      // --- 2. OBTENER LOS BALANCES DE TODOS LOS DEMÁS TOKENS (SPL) ---
      print('[Solana API] Buscando otros tokens (SPL)...');
      
      // --- ¡CORRECCIÓN FINAL Y BASADA EN EJEMPLO FUNCIONAL! ---
      // Se debe crear el objeto 'TokenAccountsFilter' de esta manera.
      const filter = TokenAccountsFilter.byProgramId(TokenProgram.programId);

      final tokenAccountsResult = await client.getTokenAccountsByOwner(
        owner.toBase58(),
        filter, // Se pasa el objeto filtro
        encoding: Encoding.jsonParsed,
      );
      
      final tokenAccounts = tokenAccountsResult.value;

      if (tokenAccounts.isEmpty) {
        print('[Solana API] No se encontraron otros tokens.');
      } else {
        print('[Solana API] Se encontraron ${tokenAccounts.length} cuentas de tokens.');
        for (final account in tokenAccounts) {
          final data = account.account.data;
          if (data is ParsedAccountData) {
            final parsed = data.parsed as Map<String, dynamic>;
            if (parsed['type'] == 'account') {
              final info = parsed['info'];
              final tokenAmount = info['tokenAmount'];
              final amount = tokenAmount['uiAmount'] as double? ?? 0.0;

              if (amount > 0) {
                final mint = info['mint'] as String;
                balances[mint] = amount;
                print('  -> Token: $mint, Cantidad: $amount');
              }
            }
          }
        }
      }
      return balances;

    } catch (e) {
      print('[Solana API] Error al obtener balances: $e');
      return balances;
    }
  }
}