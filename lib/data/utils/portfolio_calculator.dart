// lib/data/utils/portfolio_calculator.dart

import 'package:cpm/data/models/coin_models.dart';

class PortfolioCalculator {
  static List<PortfolioAsset> calculate(List<Transaction> transactions, List<CryptoCoin> marketPrices) {
    print("--- [Calculator] INICIO DEL CÁLCULO DE PORTAFOLIO ---");
    final Map<String, PortfolioAsset> portfolioMap = {};

    transactions.sort((a, b) => a.date.compareTo(b.date));

    for (var tx in transactions) {
      // --- LÓGICA DE COMPRA FIAT ---
      if (tx.type == 'buy' && tx.cryptoCoinId != null) {
        final coinInfo = marketPrices.firstWhere((c) => c.id == tx.cryptoCoinId, orElse: () => CryptoCoin(id: tx.cryptoCoinId!, name: 'Unknown', ticker: '???', price: 0));
        if (portfolioMap.containsKey(tx.cryptoCoinId)) {
          final asset = portfolioMap[tx.cryptoCoinId]!;
          final newAmount = (asset.amount ?? 0) + tx.cryptoAmount!;
          final newTotalInvested = asset.totalInvestedUSD + tx.fiatAmount!;
          
          asset.amount = newAmount;
          asset.totalInvestedUSD = newTotalInvested;
          asset.averageBuyPrice = newTotalInvested / newAmount;

        } else {
          portfolioMap[tx.cryptoCoinId!] = PortfolioAsset(
            coinId: coinInfo.id, name: coinInfo.name, ticker: coinInfo.ticker,
            amount: tx.cryptoAmount,
            averageBuyPrice: tx.fiatAmount! / tx.cryptoAmount!,
            totalInvestedUSD: tx.fiatAmount!,
          );
        }
      } 
      // --- LÓGICA DE VENTA FIAT ---
      else if (tx.type == 'sell' && tx.cryptoCoinId != null) {
        if (portfolioMap.containsKey(tx.cryptoCoinId)) {
          final asset = portfolioMap[tx.cryptoCoinId]!;
          final sellAmount = tx.cryptoAmount!;
          
          // --- ¡LÓGICA DE COSTE BASE CORREGIDA! ---
          // Reducimos el total invertido proporcionalmente a la cantidad vendida.
          if (asset.amount! > 0) {
            final proportionSold = sellAmount / asset.amount!;
            asset.totalInvestedUSD = asset.totalInvestedUSD * (1 - proportionSold);
          }
          asset.amount = asset.amount! - sellAmount;
        }
      } 
      // --- LÓGICA DE SWAP ---
      else if (tx.type == 'swap') {
        if (tx.fromCoinId != null && portfolioMap.containsKey(tx.fromCoinId)) {
          final fromAsset = portfolioMap[tx.fromCoinId]!;
          final fromAmount = tx.fromAmount!;
          
          // El valor en USD de lo que "vendimos" para hacer el swap.
          final fromMarketCoin = marketPrices.firstWhere((c) => c.id == tx.fromCoinId, orElse: () => CryptoCoin(id: tx.fromCoinId!, name: 'Unknown', ticker: '???', price: fromAsset.averageBuyPrice));
          final valueSoldUSD = fromAmount * fromMarketCoin.price;

          // --- ¡LÓGICA DE COSTE BASE CORREGIDA! ---
          if (fromAsset.amount! > 0) {
            final proportionSold = fromAmount / fromAsset.amount!;
            fromAsset.totalInvestedUSD = fromAsset.totalInvestedUSD * (1 - proportionSold);
          }
          fromAsset.amount = fromAsset.amount! - fromAmount;

          // Añadimos el nuevo activo con el coste correcto.
          final toCoinInfo = marketPrices.firstWhere((c) => c.id == tx.toCoinId, orElse: () => CryptoCoin(id: tx.toCoinId!, name: 'Unknown', ticker: '???', price: 0));
          if (portfolioMap.containsKey(tx.toCoinId)) {
            final toAsset = portfolioMap[tx.toCoinId]!;
            final newAmount = (toAsset.amount ?? 0) + tx.toAmount!;
            final newTotalInvested = toAsset.totalInvestedUSD + valueSoldUSD;
            toAsset.amount = newAmount;
            toAsset.totalInvestedUSD = newTotalInvested;
            toAsset.averageBuyPrice = newTotalInvested / newAmount;
          } else {
            portfolioMap[tx.toCoinId!] = PortfolioAsset(
              coinId: toCoinInfo.id, name: toCoinInfo.name, ticker: toCoinInfo.ticker,
              amount: tx.toAmount,
              averageBuyPrice: valueSoldUSD / tx.toAmount!,
              totalInvestedUSD: valueSoldUSD,
            );
          }
        }
      }
    }
    portfolioMap.removeWhere((key, value) => (value.amount ?? 0) < 0.000001);
    print("--- [Calculator] FIN DEL CÁLCULO ---");
    return portfolioMap.values.toList();
  }
}