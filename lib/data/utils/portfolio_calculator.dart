// lib/data/utils/portfolio_calculator.dart

import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/models/coin_models.dart';

class PortfolioCalculator {
  static List<PortfolioAsset> calculate(List<Transaction> transactions, List<CryptoCoin> marketPrices) {
    final Map<String, PortfolioAsset> portfolioMap = {};
    transactions.sort((a, b) => a.date.compareTo(b.date));

    for (var tx in transactions) {
      final type = tx.type;
      final coinId = tx.cryptoCoinId;

      if (coinId == null) continue; // Ignorar transacciones sin cripto (depósitos/retiros fiat)

      // Asegurarse de que el activo exista en el mapa
      if (!portfolioMap.containsKey(coinId)) {
        final coinInfo = marketPrices.firstWhere((c) => c.id == coinId, orElse: () => CryptoCoin(id: coinId, name: coinId, ticker: coinId.toUpperCase(), price: 0));
        portfolioMap[coinId] = PortfolioAsset(coinId: coinInfo.id, name: coinInfo.name, ticker: coinInfo.ticker, amount: 0, averageBuyPrice: 0, totalInvestedUSD: 0);
      }
      final asset = portfolioMap[coinId]!;

      if (type == 'BUY') {
        final investmentInUSD = tx.fiatAmountInUSD ?? 0.0;
        final newAmount = asset.amount! + tx.cryptoAmount!;
        final newTotalInvested = asset.totalInvestedUSD + investmentInUSD;
        asset.amount = newAmount;
        asset.totalInvestedUSD = newTotalInvested;
        asset.averageBuyPrice = newAmount > 0 ? newTotalInvested / newAmount : 0;
      } 
      else if (type == 'SELL') {
        final sellAmount = tx.cryptoAmount!;
        if (asset.amount! > 0) {
            final proportionSold = (asset.amount! < sellAmount) ? 1.0 : (sellAmount / asset.amount!);
            asset.totalInvestedUSD *= (1 - proportionSold);
        }
        asset.amount = asset.amount! - sellAmount;
      } 
      else if (type == 'SWAP') {
          // Lógica para la moneda que sale
          if (tx.fromCoinId != null && portfolioMap.containsKey(tx.fromCoinId)) {
              final fromAsset = portfolioMap[tx.fromCoinId]!;
              final fromAmount = tx.fromAmount!;
              double valueSoldUSD = 0;
              if (fromAsset.amount! > 0) {
                  final proportionSold = (fromAsset.amount! < fromAmount) ? 1.0 : (fromAmount / fromAsset.amount!);
                  valueSoldUSD = fromAsset.totalInvestedUSD * proportionSold;
                  fromAsset.totalInvestedUSD -= valueSoldUSD;
              }
              fromAsset.amount = fromAsset.amount! - fromAmount;

              // Lógica para la moneda que entra
              final toCoinId = tx.toCoinId!;
              if (!portfolioMap.containsKey(toCoinId)) {
                  final coinInfo = marketPrices.firstWhere((c) => c.id == toCoinId, orElse: () => CryptoCoin(id: toCoinId, name: toCoinId, ticker: toCoinId.toUpperCase(), price: 0));
                  portfolioMap[toCoinId] = PortfolioAsset(coinId: coinInfo.id, name: coinInfo.name, ticker: coinInfo.ticker, amount: 0, averageBuyPrice: 0, totalInvestedUSD: 0);
              }
              final toAsset = portfolioMap[toCoinId]!;
              toAsset.amount = toAsset.amount! + tx.toAmount!;
              toAsset.totalInvestedUSD += valueSoldUSD;
              toAsset.averageBuyPrice = toAsset.amount! > 0 ? toAsset.totalInvestedUSD / toAsset.amount! : 0;
          }
      }
      else if (type == 'TRANSFER_IN' || type == 'UNSTAKE') {
        asset.amount = asset.amount! + tx.cryptoAmount!;
      }
      else if (type == 'TRANSFER_OUT' || type == 'FEE' || type == 'STAKE') {
        asset.amount = asset.amount! - tx.cryptoAmount!;
      }
    }
    
    portfolioMap.removeWhere((key, value) => (value.amount ?? 0) < 0.000001);
    return portfolioMap.values.toList();
  }

  static PortfolioSummary calculateSummary({
    required List<PortfolioAsset> portfolio,
    required List<Transaction> transactions,
    required List<CryptoCoin> marketPrices,
  }) {
    double currentPortfolioValue = 0;
    for (var asset in portfolio) {
      final marketCoin = marketPrices.firstWhere((c) => c.id == asset.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0));
      currentPortfolioValue += (asset.amount ?? 0) * marketCoin.price;
    }

    final Map<String, double> investedByFiat = {};
    final Map<String, double> recoveredByFiat = {};

    for (var tx in transactions) {
      if (tx.fiatCurrency != null && tx.fiatAmount != null) {
        if (tx.type == 'DEPOSIT') {
          investedByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
        } else if (tx.type == 'WITHDRAW') {
          recoveredByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
        }
      }
    }

    final investedInUSD = transactions.where((tx) => tx.type == 'BUY').fold<double>(0.0, (sum, tx) => sum + (tx.fiatAmountInUSD ?? 0.0));
    final recoveredInUSD = transactions.where((tx) => tx.type == 'SELL').fold<double>(0.0, (sum, tx) => sum + (tx.fiatAmountInUSD ?? 0.0));
    final pnlUSD = (currentPortfolioValue + recoveredInUSD) - investedInUSD;
    final pnlPercent = investedInUSD > 0 ? (pnlUSD / investedInUSD) * 100 : 0.0;
    
    return PortfolioSummary(
      totalInvested: investedInUSD,
      currentValue: currentPortfolioValue,
      recoveredFromSales: recoveredInUSD,
      totalPnlUSD: pnlUSD,
      totalPnlPercent: pnlPercent,
      totalInvestedByFiat: investedByFiat,
      totalRecoveredByFiat: recoveredByFiat,
    );
  }
}