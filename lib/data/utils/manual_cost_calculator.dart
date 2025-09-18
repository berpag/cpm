// lib/data/utils/manual_cost_calculator.dart

import 'package:cpm/data/models/coin_models.dart';

class ManualCostCalculator {
  
  /// Calcula el precio promedio ponderado para un activo de una cuenta Manual.
  static Future<Map<String, double>> calculateWeightedAveragePrice({
    required String assetIdToCalculate,
    required List<Transaction> allManualTransactions,
  }) async {
    // 1. Asegurar orden cronológico
    allManualTransactions.sort((a, b) => a.date.compareTo(b.date));

    double currentTotalCost = 0.0;
    double currentTotalAmount = 0.0;

    // 2. Definir operaciones de Compra y Venta Manual
    final purchaseOps = ['Manual Buy', 'Manual Swap (In)'];
    final sellOps = ['Manual Sell', 'Manual Swap (Out)'];

    final assetTransactions = allManualTransactions.where(
      (tx) => tx.cryptoCoinId.toLowerCase() == assetIdToCalculate
    ).toList();

    for (final tx in assetTransactions) {
      // --- Lógica de Compra ---
      if (purchaseOps.contains(tx.type)) {
        final double amountAcquired = tx.cryptoAmount;
        // El costo es directo, no hay que buscar contrapartes.
        // Damos prioridad a usdValue si existe.
        final double costOfThisTransaction = tx.usdValue ?? tx.fiatAmount ?? 0.0;

        currentTotalCost += costOfThisTransaction;
        currentTotalAmount += amountAcquired;
      }
      // --- Lógica de Venta ---
      else if (sellOps.contains(tx.type)) {
        final double amountSold = tx.cryptoAmount.abs();
        
        if (currentTotalAmount > 0) {
          // Ajustamos la base de costos
          final double costBasisOfSale = (amountSold / currentTotalAmount) * currentTotalCost;
          currentTotalCost -= costBasisOfSale;
          currentTotalAmount -= amountSold;

          // Asegurarse de que el costo no se vuelva negativo por errores de precisión
          if (currentTotalCost < 0) currentTotalCost = 0;
        }
      }
    }

    final double finalAveragePrice = (currentTotalAmount > 0) ? currentTotalCost / currentTotalAmount : 0.0;

    print('[ManualCostCalculator] Cálculo finalizado para $assetIdToCalculate:');
    print(' -> Costo Total de Base Restante: \$${currentTotalCost.toStringAsFixed(4)}');
    print(' -> Cantidad Total Restante: $currentTotalAmount');
    print(' -> Precio Promedio Ponderado Final: \$${finalAveragePrice.toStringAsFixed(4)}');

    return {
      'totalInvestedUSD': currentTotalCost,
      'averageBuyPrice': finalAveragePrice,
    };
  }
}