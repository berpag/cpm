// lib/data/utils/binance_cost_calculator.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/binance_api_service.dart';

class BinanceCostCalculator {
  
  /// Calcula el precio promedio ponderado para un activo de Binance,
  /// basándose en las compras "reales" y ajustando por ventas.
  static Future<Map<String, double>> calculateWeightedAveragePrice({
    required String assetIdToCalculate,
    required List<Transaction> allBinanceTransactions,
  }) async {
    
    // 1. Asegurar orden cronológico
    allBinanceTransactions.sort((a, b) => a.date.compareTo(b.date));

    double currentTotalCost = 0.0;
    double currentTotalAmount = 0.0;

    // 2. Definir qué operaciones cuentan como compras o ventas
    final realPurchaseOps = ['Binance Convert', 'Transaction Buy'];
    final sellOps = ['Transaction Sold', 'Binance Convert'];

    // 3. Agrupar por timestamp para procesar cada evento atómicamente
    final transactionsByTime = <DateTime, List<Transaction>>{};
    for (final tx in allBinanceTransactions) {
      transactionsByTime.putIfAbsent(tx.date, () => []).add(tx);
    }

    for (final entry in transactionsByTime.entries) {
      final timestamp = entry.key;
      final group = entry.value;

      // --- Lógica de Compra ---
      final purchases = group.where((tx) =>
          tx.cryptoCoinId.toLowerCase() == assetIdToCalculate &&
          tx.cryptoAmount > 0 &&
          realPurchaseOps.contains(tx.type)).toList();
      
      if (purchases.isNotEmpty) {
        final double amountAcquiredGross = purchases.fold(0, (sum, tx) => sum + tx.cryptoAmount);
        
        // Buscar costos y comisiones en el mismo evento
        final costOperations = ['Binance Convert', 'Transaction Spend', 'Transaction Fee'];
        final counterparts = group.where((tx) => tx.cryptoAmount < 0 && costOperations.contains(tx.type)).toList();

        double costOfThisEvent = 0.0;
        double feesInAssetThisEvent = 0.0;

        for (final row in counterparts) {
          final sourceCoin = row.cryptoCoinId.toLowerCase();
          final sourceAmount = row.cryptoAmount.abs();

          if (sourceCoin == assetIdToCalculate && row.type == 'Transaction Fee') {
            feesInAssetThisEvent += sourceAmount;
            continue;
          }

          double? costOfThisCounterpart;
          if (['usdt', 'usdc', 'busd', 'fdusd'].contains(sourceCoin)) {
            costOfThisCounterpart = sourceAmount;
          } else {
            final symbol = '${sourceCoin.toUpperCase()}USDT';
            final price = await BinanceApiService.getHistoricalPriceAtTime(symbol, timestamp);
            if (price != null) {
              costOfThisCounterpart = sourceAmount * price;
            }
          }
          if (costOfThisCounterpart != null) {
            costOfThisEvent += costOfThisCounterpart;
          }
        }

        final double netAmountAcquired = amountAcquiredGross - feesInAssetThisEvent;
        if (netAmountAcquired <= 0) continue;

        currentTotalCost += costOfThisEvent;
        currentTotalAmount += netAmountAcquired;
      }

      // --- Lógica de Venta ---
      final sells = group.where((tx) =>
          tx.cryptoCoinId.toLowerCase() == assetIdToCalculate &&
          tx.cryptoAmount < 0 &&
          sellOps.contains(tx.type)).toList();

      if (sells.isNotEmpty) {
        final double amountSold = sells.fold(0, (sum, tx) => sum + tx.cryptoAmount.abs());
        if (currentTotalAmount > 0 && currentTotalAmount >= amountSold) {
          final costBasisOfSale = (amountSold / currentTotalAmount) * currentTotalCost;
          currentTotalCost -= costBasisOfSale;
          currentTotalAmount -= amountSold;
        }
      }
    }

    final double finalAveragePrice = (currentTotalAmount > 0) ? currentTotalCost / currentTotalAmount : 0.0;

    print('[BinanceCostCalculator] Cálculo finalizado para $assetIdToCalculate:');
    print(' -> Costo Total de Base Restante: \$${currentTotalCost.toStringAsFixed(4)}');
    print(' -> Cantidad Total Restante: $currentTotalAmount');
    print(' -> Precio Promedio Ponderado Final: \$${finalAveragePrice.toStringAsFixed(4)}');

    return {
      'totalInvestedUSD': currentTotalCost,
      'averageBuyPrice': finalAveragePrice,
    };
  }
}