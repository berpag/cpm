// lib/data/utils/portfolio_calculator.dart

import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/utils/binance_calculator.dart';
import 'package:cpm/data/utils/manual_calculator.dart';

class PortfolioCalculator {
  static final _binanceCalculator = BinanceCalculator();
  static final _manualCalculator = ManualCalculator();

  static Future<List<PortfolioAsset>> calculate({
    required List<Transaction> allTransactions,
    required List<CryptoCoin> marketPrices,
    String? sourceAccount,
  }) async {
    allTransactions.sort((a, b) => a.date.compareTo(b.date));

    if (sourceAccount == null) {
      print("\n--- 📊 CALCULANDO PORTAFOLIO GLOBAL 📊 ---");
      return _calculateForAllSources(allTransactions, marketPrices);
    }

    print("\n--- 📄 CALCULANDO PARA FUENTE ÚNICA: $sourceAccount 📄 ---");
    final transactionsToProcess = allTransactions.where((tx) => tx.sourceAccount == sourceAccount).toList();
    switch (sourceAccount) {
      case 'Binance':
        return _binanceCalculator.calculate(transactions: transactionsToProcess, marketPrices: marketPrices);
      case 'Manual':
        return _manualCalculator.calculate(transactions: transactionsToProcess, marketPrices: marketPrices);
      default:
        return [];
    }
  }

  static Future<List<PortfolioAsset>> _calculateForAllSources(
    List<Transaction> allTransactions,
    List<CryptoCoin> marketPrices
  ) async {
    final transactionsBySource = <String, List<Transaction>>{};
    for (final tx in allTransactions) {
      (transactionsBySource[tx.sourceAccount] ??= []).add(tx);
    }
    
    print("[Global Calculator] Fuentes encontradas: ${transactionsBySource.keys.join(', ')}");

    final allCalculations = transactionsBySource.entries.map((entry) {
      final source = entry.key;
      final transactions = entry.value;
      print("[Global Calculator] Delegando cálculo para la fuente: '$source' con ${transactions.length} transacciones.");
      
      switch (source) {
        case 'Binance':
          return _binanceCalculator.calculate(transactions: transactions, marketPrices: marketPrices);
        case 'Manual':
          return _manualCalculator.calculate(transactions: transactions, marketPrices: marketPrices);
        default:
          return Future.value(<PortfolioAsset>[]);
      }
    });

    final resultsFromAllSources = await Future.wait(allCalculations);
    
    print("\n--- CONSOLIDANDO RESULTADOS ---");
    final consolidatedPortfolio = <String, PortfolioAsset>{};

    for (final assetList in resultsFromAllSources) {
      for (final asset in assetList) {
        print("[Consolidator] Procesando: ${asset.ticker} (${asset.sourceAccount}), Total: ${asset.totalAmount}");
        
        final existingAsset = consolidatedPortfolio[asset.coinId];

        if (existingAsset != null) {
          print("[Consolidator] -> Encontrado. Sumando balances...");
          existingAsset.totalInvestedUSD += asset.totalInvestedUSD;
          asset.balances.forEach((wallet, amount) {
            existingAsset.balances.update(wallet, (value) => value + amount, ifAbsent: () => amount);
          });
           print("[Consolidator] -> Después de sumar: ${existingAsset.ticker} Total=${existingAsset.totalAmount}");
        } else {
          print("[Consolidator] -> No encontrado. Creando nuevo activo consolidado para ${asset.ticker}");
          consolidatedPortfolio[asset.coinId] = PortfolioAsset(
            sourceAccount: 'Global',
            coinId: asset.coinId,
            name: asset.name,
            ticker: asset.ticker,
            balances: Map<String, double>.from(asset.balances),
            totalInvestedUSD: asset.totalInvestedUSD,
          );
        }
      }
    }

    consolidatedPortfolio.forEach((key, asset) {
      asset.averageBuyPrice = asset.totalAmount > 0 ? asset.totalInvestedUSD / asset.totalAmount : 0;
    });
    
    print("--- ✅ Consolidación Finalizada. Total de activos únicos: ${consolidatedPortfolio.length} ---");
    return consolidatedPortfolio.values.toList();
  }
  
  static Future<PortfolioSummary> calculateSummary({
    required List<Transaction> allTransactions,
    required List<CryptoCoin> marketPrices,
    String? sourceAccount,
  }) async {
    final portfolio = await calculate(
      allTransactions: allTransactions,
      marketPrices: marketPrices,
      sourceAccount: sourceAccount
    );

    double currentPortfolioValue = 0, totalPortfolioInvested = 0;
    for (var asset in portfolio) {
      final marketCoin = marketPrices.firstWhere((c) => c.id == asset.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0.0));
      currentPortfolioValue += asset.totalAmount * marketCoin.price;
      totalPortfolioInvested += asset.totalInvestedUSD;
    }

    final transactionsToProcess = sourceAccount == null 
        ? allTransactions 
        : allTransactions.where((tx) => tx.sourceAccount == sourceAccount).toList();
    
    final Map<String, double> investedByFiat = {}, recoveredByFiat = {};
    for (var tx in transactionsToProcess) {
      if (tx.fiatCurrency != null && tx.fiatAmount != null) {
        if (tx.type == 'Manual Buy' || tx.type == 'Buy') {
          investedByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
        } else if (tx.type == 'Manual Sell' || tx.type == 'Sell') {
          recoveredByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
        }
      }
    }

    final recoveredInUSD = transactionsToProcess
        .where((tx) => tx.type == 'Manual Sell' || tx.type == 'Sell')
        .fold<double>(0.0, (sum, tx) => sum + (tx.usdValue ?? tx.fiatAmount ?? 0.0));
    
    final pnlUSD = (currentPortfolioValue + recoveredInUSD) - totalPortfolioInvested;
    final pnlPercent = totalPortfolioInvested > 0 ? (pnlUSD / totalPortfolioInvested) * 100 : 0.0;
    
    return PortfolioSummary(
      totalInvested: totalPortfolioInvested, currentValue: currentPortfolioValue,
      recoveredFromSales: recoveredInUSD, totalPnlUSD: pnlUSD,
      totalPnlPercent: pnlPercent, totalInvestedByFiat: investedByFiat,
      totalRecoveredByFiat: recoveredByFiat,
    );
  }
}