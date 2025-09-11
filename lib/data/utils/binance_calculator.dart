// lib/data/utils/binance_calculator.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/utils/base_calculator.dart';

class BinanceCalculator implements BasePortfolioCalculator {

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
          sourceAccount: 'Binance',
          coinId: coinId,
          name: ticker,
          ticker: ticker,
          balances: {},
        );
      });

      final asset = portfolio[coinId]!;
      
      asset.balances.putIfAbsent('Spot', () => 0.0);
      asset.balances.putIfAbsent('Funding', () => 0.0);
      asset.balances.putIfAbsent('Earn', () => 0.0);

      final walletFromCsv = tx.wallet;
      final operation = tx.type;
      final change = tx.cryptoAmount;
      
      if (operation == 'Transfer Between Main and Funding Wallet') {
        if (walletFromCsv == 'Spot') {
          asset.balances['Spot'] = asset.balances['Spot']! + change;
          asset.balances['Funding'] = asset.balances['Funding']! - change;
        } else {
          asset.balances['Funding'] = asset.balances['Funding']! + change;
          asset.balances['Spot'] = asset.balances['Spot']! - change;
        }
      }
      else if (operation == 'Simple Earn Flexible Subscription') {
        asset.balances['Spot'] = asset.balances['Spot']! + change;
        asset.balances['Earn'] = asset.balances['Earn']! + change.abs();
      } 
      else if (operation == 'Simple Earn Flexible Redemption') {
        // El 'change' del CSV es el monto exacto que se acredita en Spot.
        // Y la billetera Earn se vacía por completo en este evento.
        asset.balances['Spot'] = asset.balances['Spot']! + change;
        asset.balances['Earn'] = 0.0;
      } 
      else if (operation == 'Simple Earn Flexible Interest') {
        asset.balances['Earn'] = asset.balances['Earn']! + change;
      }
      else {
        asset.balances.putIfAbsent(walletFromCsv, () => 0.0);
        asset.balances[walletFromCsv] = asset.balances[walletFromCsv]! + change;
      }
    }
    
    portfolio.removeWhere((key, asset) => asset.totalAmount.abs() < 1e-9);

    portfolio.forEach((key, asset) {
      asset.balances.removeWhere((wallet, amount) => amount.abs() < 1e-9);
    });
    
    portfolio.removeWhere((key, asset) => asset.balances.isEmpty);

    return portfolio.values.toList();
  }
}