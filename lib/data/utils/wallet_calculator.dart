// lib/data/utils/wallet_calculator.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/utils/base_calculator.dart';

class WalletCalculator implements BasePortfolioCalculator {
  
  @override
  Future<List<PortfolioAsset>> calculate({
    required List<Transaction> transactions,
    required List<CryptoCoin> marketPrices,
  }) async {
    final Map<String, PortfolioAsset> portfolio = {};

    for (var tx in transactions) {
      // Las transacciones de balance solo tienen un tipo, 'Balance Sync'
      if (tx.type == 'Balance Sync') {
        final coinId = tx.cryptoCoinId;

        portfolio.putIfAbsent(coinId, () {
          return PortfolioAsset(
            sourceAccount: tx.sourceAccount, 
            coinId: coinId,
            name: '', // Lo obtenemos de otras fuentes
            ticker: coinId.toUpperCase(), // Usamos el ID como ticker temporal
            balances: {},
          );
        });

        final asset = portfolio[coinId]!;
        // Para las wallets, el nombre de la billetera es la red
        asset.balances.update(tx.wallet, (value) => value + tx.cryptoAmount, ifAbsent: () => tx.cryptoAmount);
      }
    }
    
    // Eliminamos activos con balance cero
    portfolio.removeWhere((key, asset) {
      asset.balances.removeWhere((wallet, amount) => amount.abs() < 1e-9);
      return asset.balances.isEmpty || asset.totalAmount.abs() < 1e-9;
    });

    return portfolio.values.toList();
  }
}