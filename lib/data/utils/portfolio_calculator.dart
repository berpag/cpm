// lib/data/utils/portfolio_calculator.dart

import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/models/coin_models.dart';

class PortfolioCalculator {
  static List<PortfolioAsset> calculate(List<Transaction> allTransactions, List<CryptoCoin> marketPrices, {String? sourceAccount}) {
    final transactions = sourceAccount == null
        ? allTransactions
        : allTransactions.where((tx) => tx.sourceAccount == sourceAccount).toList();

    transactions.sort((a, b) => a.date.compareTo(b.date));
    
    final Map<String, PortfolioAsset> portfolio = {};

    for (var tx in transactions) {
      final coinId = tx.cryptoCoinId;
      if (coinId == null) continue;

      portfolio.putIfAbsent(coinId, () {
        final marketInfo = marketPrices.firstWhere(
          (c) => c.id == coinId, 
          orElse: () => CryptoCoin(id: coinId, name: coinId.toUpperCase(), ticker: coinId.toUpperCase(), price: 0)
        );
        return PortfolioAsset(
          coinId: coinId, name: marketInfo.name, ticker: marketInfo.ticker,
          balances: {},
        );
      });

      final asset = portfolio[coinId]!;
      final operation = tx.type;
      final change = tx.cryptoAmount;
      
      asset.balances.putIfAbsent('Spot', () => 0.0);
      asset.balances.putIfAbsent('Earn', () => 0.0);
      asset.balances.putIfAbsent(tx.wallet, () => 0.0);

      if (operation == 'Simple Earn Flexible Subscription') {
        asset.balances[tx.wallet] = asset.balances[tx.wallet]! + change;
        asset.balances['Earn'] = asset.balances['Earn']! + change.abs();
      } else if (operation == 'Simple Earn Flexible Redemption') {
        asset.balances[tx.wallet] = asset.balances[tx.wallet]! + change;
        asset.balances['Earn'] = 0.0;
      } else if (operation == 'Simple Earn Flexible Interest') {
        asset.balances['Earn'] = asset.balances['Earn']! + change;
      } else {
        asset.balances[tx.wallet] = asset.balances[tx.wallet]! + change;
      }
    }
    
    portfolio.removeWhere((key, asset) {
      asset.balances.removeWhere((wallet, amount) => amount.abs() < 0.00000001);
      return asset.balances.isEmpty || asset.totalAmount.abs() < 0.00000001;
    });
    
    portfolio.forEach((key, asset) {
      asset.averageBuyPrice = asset.totalAmount > 0 ? asset.totalInvestedUSD / asset.totalAmount : 0;
    });

    return portfolio.values.toList();
  }
  
  
  // ... (El resto del archivo no cambia)

  
  static PortfolioSummary calculateSummary({
    required List<PortfolioAsset> portfolio,
    required List<Transaction> allTransactions,
    required List<CryptoCoin> marketPrices,
    String? sourceAccount,
  }) {
    double currentPortfolioValue = 0;
    double totalPortfolioInvested = 0;

    for (var asset in portfolio) {
      final marketCoin = marketPrices.firstWhere(
        (c) => c.id == asset.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0));
      currentPortfolioValue += asset.totalAmount * marketCoin.price; // Usamos el totalAmount
      totalPortfolioInvested += asset.totalInvestedUSD;
    }

    final transactionsToProcess = sourceAccount == null
        ? allTransactions
        : allTransactions.where((tx) => tx.sourceAccount == sourceAccount).toList();

    final Map<String, double> investedByFiat = {};
    final Map<String, double> recoveredByFiat = {};

    for (var tx in transactionsToProcess) {
      // Esta parte requiere el modelo de transacción antiguo.
      // Lo dejamos así por ahora, ya que no estamos usando FiatAnalysisScreen activamente.
      // if (tx.fiatCurrency != null && tx.fiatAmount != null) {
      //   if (tx.type == 'buy') {
      //     investedByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
      //   } else if (tx.type == 'sell') {
      //     recoveredByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
      //   }
      // }
    }
    
    final recoveredInUSD = transactionsToProcess.where((tx) => tx.type == 'sell')
        .fold<double>(0.0, (sum, tx) => sum + 0.0 /*(tx.fiatAmountInUSD ?? tx.fiatAmount ?? 0.0)*/);

    final pnlUSD = currentPortfolioValue - totalPortfolioInvested;
    final pnlPercent = totalPortfolioInvested > 0 ? (pnlUSD / totalPortfolioInvested) * 100 : 0.0;
    
    return PortfolioSummary(
      totalInvested: totalPortfolioInvested,
      currentValue: currentPortfolioValue,
      recoveredFromSales: recoveredInUSD,
      totalPnlUSD: pnlUSD,
      totalPnlPercent: pnlPercent,
      totalInvestedByFiat: investedByFiat,
      totalRecoveredByFiat: recoveredByFiat,
    );
  }

  static bool _isFiat(String coinId) {
    const fiats = ['colombian-peso', 'usd', 'eur'];
    return fiats.contains(coinId.toLowerCase());
  }
}