// lib/data/utils/manual_calculator.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/utils/base_calculator.dart';

class ManualCalculator implements BasePortfolioCalculator {
  
  @override
  Future<List<PortfolioAsset>> calculate({
    required List<Transaction> transactions,
    required List<CryptoCoin> marketPrices,
  }) async {
    final Map<String, PortfolioAsset> portfolio = {};

    for (var tx in transactions) {
      final coinId = tx.cryptoCoinId.toLowerCase();

      portfolio.putIfAbsent(coinId, () {
        final ticker = tx.cryptoCoinId.toUpperCase();
        return PortfolioAsset(
          sourceAccount: 'Manual', 
          coinId: coinId, 
          name: ticker,
          ticker: ticker, 
          balances: {},
        );
      });

      final asset = portfolio[coinId]!;
      asset.balances.update(tx.wallet, (value) => value + tx.cryptoAmount, ifAbsent: () => tx.cryptoAmount);
      
      // La lógica de inversión se moverá a una fase posterior.
      if (tx.type == 'Manual Buy') {
        asset.totalInvestedUSD += tx.usdValue ?? tx.fiatAmount ?? 0.0;
      } else if (tx.type == 'Manual Sell') {
        final totalAmountBeforeTx = asset.totalAmount - tx.cryptoAmount; // Reconstruimos el total antes de la venta
        if (totalAmountBeforeTx > 0) {
          final percentageSold = tx.cryptoAmount.abs() / totalAmountBeforeTx;
          asset.totalInvestedUSD -= asset.totalInvestedUSD * percentageSold;
        }
      }
    }
    
    portfolio.removeWhere((key, asset) {
      asset.balances.removeWhere((wallet, amount) => amount.abs() < 1e-9);
      return asset.balances.isEmpty || asset.totalAmount.abs() < 1e-9;
    });

    return portfolio.values.toList();
  }
}