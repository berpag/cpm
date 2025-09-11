// lib/data/utils/portfolio_calculator.dart

import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/utils/binance_calculator.dart';
import 'package:cpm/data/utils/manual_calculator.dart';

class PortfolioCalculator {
  static final _binanceCalculator = BinanceCalculator();
  static final _manualCalculator = ManualCalculator();
  // TODO: Añadir aquí futuros calculadores (ej. PhantomCalculator)

  /// El orquestador principal.
  /// Filtra transacciones por `sourceAccount` o consolida todas las fuentes.
  static Future<List<PortfolioAsset>> calculate({
    required List<Transaction> allTransactions,
    required List<CryptoCoin> marketPrices,
    String? sourceAccount,
  }) async {
    // Ordenamos la lista completa UNA SOLA VEZ al principio.
    allTransactions.sort((a, b) => a.date.compareTo(b.date));

    // Si no se especifica una fuente, calculamos el portafolio global consolidado.
    if (sourceAccount == null) {
      return _calculateForAllSources(allTransactions, marketPrices);
    }

    // Si se especifica una fuente, filtramos y delegamos al calculador correspondiente.
    final transactionsToProcess = allTransactions.where((tx) => tx.sourceAccount == sourceAccount).toList();
    switch (sourceAccount) {
      case 'Binance':
        return _binanceCalculator.calculate(transactions: transactionsToProcess, marketPrices: marketPrices);
      case 'Manual':
        return _manualCalculator.calculate(transactions: transactionsToProcess, marketPrices: marketPrices);
      // TODO: Añadir aquí casos para futuras fuentes (ej. 'Phantom')
      default:
        return []; // Devolvemos una lista vacía si la fuente no es reconocida.
    }
  }

  /// Calcula y consolida los portafolios de todas las fuentes.
  static Future<List<PortfolioAsset>> _calculateForAllSources(
    List<Transaction> allTransactions,
    List<CryptoCoin> marketPrices
  ) async {
    // Agrupamos las transacciones por su fuente.
    final transactionsBySource = <String, List<Transaction>>{};
    for (final tx in allTransactions) {
      (transactionsBySource[tx.sourceAccount] ??= []).add(tx);
    }
    
    // Ejecutamos todos los cálculos en paralelo.
    final allCalculations = transactionsBySource.entries.map((entry) {
      final source = entry.key;
      final transactions = entry.value;
      
      switch (source) {
        case 'Binance':
          return _binanceCalculator.calculate(transactions: transactions, marketPrices: marketPrices);
        case 'Manual':
          return _manualCalculator.calculate(transactions: transactions, marketPrices: marketPrices);
        default:
          return Future.value(<PortfolioAsset>[]);
      }
    });

    // Esperamos a que todos los cálculos terminen.
    final resultsFromAllSources = await Future.wait(allCalculations);
    
    // Consolidamos los resultados.
    final consolidatedPortfolio = <String, PortfolioAsset>{};

    for (final assetList in resultsFromAllSources) {
      for (final asset in assetList) {
        consolidatedPortfolio.putIfAbsent(
          asset.coinId,
          () => PortfolioAsset(
            sourceAccount: 'Global',
            coinId: asset.coinId,
            name: asset.name,
            ticker: asset.ticker,
            balances: {},
            totalInvestedUSD: 0.0,
          ),
        );

        final existingAsset = consolidatedPortfolio[asset.coinId]!;
        existingAsset.totalInvestedUSD += asset.totalInvestedUSD;
        asset.balances.forEach((wallet, amount) {
          existingAsset.balances.update(wallet, (value) => value + amount, ifAbsent: () => amount);
        });
      }
    }

    // Calculamos el precio promedio de compra para el portafolio consolidado.
    consolidatedPortfolio.forEach((key, asset) {
      asset.averageBuyPrice = asset.totalAmount > 0 ? asset.totalInvestedUSD / asset.totalAmount : 0;
    });

    return consolidatedPortfolio.values.toList();
  }
  
  /// Calcula el resumen del portafolio (total invertido, valor actual, PnL).
  static Future<PortfolioSummary> calculateSummary({
    required List<Transaction> allTransactions,
    required List<CryptoCoin> marketPrices,
  }) async {
    // Obtenemos el portafolio consolidado para asegurar que los datos son correctos.
    final portfolio = await calculate(
      allTransactions: allTransactions,
      marketPrices: marketPrices,
    );

    double currentPortfolioValue = 0, totalPortfolioInvested = 0;
    for (var asset in portfolio) {
      final marketCoin = marketPrices.firstWhere((c) => c.id == asset.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0.0));
      currentPortfolioValue += asset.totalAmount * marketCoin.price;
      totalPortfolioInvested += asset.totalInvestedUSD;
    }
    
    final Map<String, double> investedByFiat = {}, recoveredByFiat = {};
    for (var tx in allTransactions) { // Usamos todas las transacciones para el resumen de fiat
      if (tx.fiatCurrency != null && tx.fiatAmount != null) {
        if (tx.type == 'Manual Buy' || tx.type == 'Buy') {
          investedByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
        } else if (tx.type == 'Manual Sell' || tx.type == 'Sell') {
          recoveredByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
        }
      }
    }

    final recoveredInUSD = allTransactions
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