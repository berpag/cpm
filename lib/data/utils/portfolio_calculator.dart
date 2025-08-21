// lib/data/utils/portfolio_calculator.dart

import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/models/coin_models.dart';

class PortfolioCalculator {
  // --- FUNCIÓN 'calculate' ACTUALIZADA ---
  static List<PortfolioAsset> calculate(List<Transaction> transactions, List<CryptoCoin> marketPrices) {
    print("--- [Calculator] INICIO DEL CÁLCULO DE PORTAFOLIO ---");
    final Map<String, PortfolioAsset> portfolioMap = {};

    transactions.sort((a, b) => a.date.compareTo(b.date));
    
    print("[Calculator] Se procesarán ${transactions.length} transacciones en orden cronológico.");

    for (var i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      print("\n[Calculator] Procesando Tx ${i + 1}/${transactions.length} | Tipo: ${tx.type} | Fecha: ${tx.date}");

      if (tx.type == 'buy' && tx.cryptoCoinId != null) {
        print("[Calculator] -> Compra de ${tx.cryptoAmount} ${tx.cryptoCoinId} por ${tx.fiatAmount} ${tx.fiatCurrency}");
        final coinInfo = marketPrices.firstWhere((c) => c.id == tx.cryptoCoinId, orElse: () => CryptoCoin(id: tx.cryptoCoinId!, name: 'Unknown', ticker: '???', price: 0));
        
        // --- ¡CAMBIO CLAVE! Usamos el valor en USD para los cálculos ---
        final investmentInUSD = tx.fiatAmountInUSD ?? tx.fiatAmount!;
        
        if (portfolioMap.containsKey(tx.cryptoCoinId)) {
          final asset = portfolioMap[tx.cryptoCoinId]!;
          print("[Calculator]   -> Activo existente. Saldo anterior: ${asset.amount}");
          final newAmount = (asset.amount ?? 0) + tx.cryptoAmount!;
          final newTotalInvested = asset.totalInvestedUSD + investmentInUSD;
          
          asset.amount = newAmount;
          asset.totalInvestedUSD = newTotalInvested;
          asset.averageBuyPrice = newAmount > 0 ? newTotalInvested / newAmount : 0;
          print("[Calculator]   -> Saldo actualizado: ${asset.amount}");
        } else {
          print("[Calculator]   -> Nuevo activo añadido al portafolio.");
          portfolioMap[tx.cryptoCoinId!] = PortfolioAsset(
            coinId: coinInfo.id, name: coinInfo.name, ticker: coinInfo.ticker,
            amount: tx.cryptoAmount,
            averageBuyPrice: tx.cryptoAmount! > 0 ? investmentInUSD / tx.cryptoAmount! : 0,
            totalInvestedUSD: investmentInUSD,
          );
        }
      } 
      else if (tx.type == 'sell' && tx.cryptoCoinId != null) {
        print("[Calculator] -> Venta de ${tx.cryptoAmount} ${tx.cryptoCoinId} por ${tx.fiatAmount} ${tx.fiatCurrency}");
        if (portfolioMap.containsKey(tx.cryptoCoinId)) {
          final asset = portfolioMap[tx.cryptoCoinId]!;
          print("[Calculator]   -> Activo existente. Saldo anterior: ${asset.amount}");
          final sellAmount = tx.cryptoAmount!;
          
          if ((asset.amount ?? 0) > 0) {
            final proportionSold = sellAmount / asset.amount!;
            asset.totalInvestedUSD = asset.totalInvestedUSD * (1 - proportionSold);
          }
          asset.amount = (asset.amount ?? 0) - sellAmount;
          print("[Calculator]   -> Saldo actualizado: ${asset.amount}");
        } else {
          print("[Calculator]   -> ADVERTENCIA: Se intentó vender un activo (${tx.cryptoCoinId}) que no existe en el portafolio.");
        }
      } 
      else if (tx.type == 'swap') {
        // La lógica de swap ya opera en USD, por lo que no necesita grandes cambios.
        print("[Calculator] -> Swap de ${tx.fromAmount} ${tx.fromCoinId} a ${tx.toAmount} ${tx.toCoinId}");
        if (tx.fromCoinId != null && portfolioMap.containsKey(tx.fromCoinId)) {
          final fromAsset = portfolioMap[tx.fromCoinId]!;
          final fromAmount = tx.fromAmount!;
          final fromMarketCoin = marketPrices.firstWhere((c) => c.id == tx.fromCoinId, orElse: () => CryptoCoin(id: tx.fromCoinId!, name: 'Unknown', ticker: '???', price: fromAsset.averageBuyPrice));
          final valueSoldUSD = fromAmount * fromMarketCoin.price;

          if (fromAsset.amount! > 0) {
            final proportionSold = fromAmount / fromAsset.amount!;
            fromAsset.totalInvestedUSD = fromAsset.totalInvestedUSD * (1 - proportionSold);
          }
          fromAsset.amount = fromAsset.amount! - fromAmount;

          final toCoinInfo = marketPrices.firstWhere((c) => c.id == tx.toCoinId, orElse: () => CryptoCoin(id: tx.toCoinId!, name: 'Unknown', ticker: '???', price: 0));
          if (portfolioMap.containsKey(tx.toCoinId)) {
            final toAsset = portfolioMap[tx.toCoinId]!;
            final newAmount = (toAsset.amount ?? 0) + tx.toAmount!;
            final newTotalInvested = toAsset.totalInvestedUSD + valueSoldUSD;
            toAsset.amount = newAmount;
            toAsset.totalInvestedUSD = newTotalInvested;
            toAsset.averageBuyPrice = newAmount > 0 ? newTotalInvested / newAmount : 0;
          } else {
            portfolioMap[tx.toCoinId!] = PortfolioAsset(
              coinId: toCoinInfo.id, name: toCoinInfo.name, ticker: toCoinInfo.ticker,
              amount: tx.toAmount,
              averageBuyPrice: tx.toAmount! > 0 ? valueSoldUSD / tx.toAmount! : 0,
              totalInvestedUSD: valueSoldUSD,
            );
          }
        }
      }
    }
    
    print("\n[Calculator] --- ESTADO FINAL DEL PORTAFOLIO (ANTES DE LIMPIEZA) ---");
    portfolioMap.forEach((key, value) {
      print("[Calculator] -> ${value.ticker}: ${value.amount} unidades, Invertido: ${value.totalInvestedUSD} USD");
    });
    
    portfolioMap.removeWhere((key, value) => (value.amount ?? 0) < 0.000001);
    
    print("\n[Calculator] --- ESTADO FINAL DEL PORTAFOLIO (DESPUÉS DE LIMPIEZA) ---");
    portfolioMap.forEach((key, value) {
      print("[Calculator] -> ${value.ticker}: ${value.amount} unidades");
    });

    print("\n--- [Calculator] FIN DEL CÁLCULO. Activos resultantes: ${portfolioMap.length} ---");
    return portfolioMap.values.toList();
  }

  // Dentro de la clase PortfolioCalculator, reemplaza esta función:

  static PortfolioSummary calculateSummary({
    required List<PortfolioAsset> portfolio,
    required List<Transaction> transactions,
    required List<CryptoCoin> marketPrices,
  }) {
    double currentPortfolioValue = 0;
    double totalPortfolioInvested = 0;

    for (var asset in portfolio) {
      final marketCoin = marketPrices.firstWhere(
        (c) => c.id == asset.coinId,
        orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0),
      );
      currentPortfolioValue += (asset.amount ?? 0) * marketCoin.price;
      totalPortfolioInvested += asset.totalInvestedUSD;
    }

    // --- ¡NUEVA LÓGICA DE AGRUPACIÓN! ---
    final Map<String, double> investedByFiat = {};
    final Map<String, double> recoveredByFiat = {};

    for (var tx in transactions) {
      if (tx.fiatCurrency != null && tx.fiatAmount != null) {
        if (tx.type == 'buy') {
          // Si es una compra, lo sumamos al total invertido de esa moneda
          investedByFiat.update(
            tx.fiatCurrency!,
            (value) => value + tx.fiatAmount!,
            ifAbsent: () => tx.fiatAmount!,
          );
        } else if (tx.type == 'sell') {
          // Si es una venta, lo sumamos al total recuperado de esa moneda
          recoveredByFiat.update(
            tx.fiatCurrency!,
            (value) => value + tx.fiatAmount!,
            ifAbsent: () => tx.fiatAmount!,
          );
        }
      }
    }
    // ------------------------------------

    // Mantenemos el cálculo del "recuperado total en USD" para el resumen principal
    final recoveredInUSD = transactions
        .where((tx) => tx.type == 'sell')
        .fold<double>(0.0, (sum, tx) => sum + (tx.fiatAmountInUSD ?? tx.fiatAmount ?? 0.0));

    final pnlUSD = currentPortfolioValue - totalPortfolioInvested;
    final pnlPercent = totalPortfolioInvested > 0 ? (pnlUSD / totalPortfolioInvested) * 100 : 0.0;
    
    return PortfolioSummary(
      totalInvested: totalPortfolioInvested,
      currentValue: currentPortfolioValue,
      recoveredFromSales: recoveredInUSD,
      totalPnlUSD: pnlUSD,
      totalPnlPercent: pnlPercent,
      // Pasamos los nuevos mapas al constructor
      totalInvestedByFiat: investedByFiat,
      totalRecoveredByFiat: recoveredByFiat,
    );
  }
}