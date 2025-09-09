// lib/data/utils/portfolio_calculator.dart

import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/models/coin_models.dart';

// --- ¡NUEVO! Lista de monedas fiat conocidas ---
const List<String> _fiatCurrencies = ['COP', 'USD', 'EUR', 'ARS', 'BRL', 'MXN'];

class PortfolioCalculator {
  static List<PortfolioAsset> calculate(List<Transaction> allTransactions, List<CryptoCoin> marketPrices, {String? sourceAccount}) {
    var transactions = sourceAccount == null
        ? allTransactions
        : allTransactions.where((tx) => tx.sourceAccount == sourceAccount).toList();

    transactions.sort((a, b) => a.date.compareTo(b.date));
    
    final processedTransactions = <Transaction>[];
    final convertPairs = <DateTime, Transaction>{};

    for (final tx in transactions) {
      if (tx.type == 'Binance Convert') {
        if (convertPairs.containsKey(tx.date)) {
          final pairTx = convertPairs.remove(tx.date)!;
          
          bool txIsFiat = _fiatCurrencies.contains(tx.cryptoCoinId.toUpperCase());
          bool pairTxIsFiat = _fiatCurrencies.contains(pairTx.cryptoCoinId.toUpperCase());

          // --- LÓGICA MEJORADA PARA MANEJAR TODOS LOS CASOS DE CONVERSIÓN ---

          // Caso 1: FIAT <-> CRIPTO
          if (txIsFiat != pairTxIsFiat) {
            final fiatTx = txIsFiat ? tx : pairTx;
            final cryptoTx = txIsFiat ? pairTx : tx;

            // La transacción fiat es negativa (gasto) y la cripto es positiva (compra)
            if (fiatTx.cryptoAmount < 0 && cryptoTx.cryptoAmount > 0) {
              processedTransactions.add(
                Transaction(
                  sourceAccount: cryptoTx.sourceAccount, type: 'Buy', date: cryptoTx.date,
                  wallet: cryptoTx.wallet, cryptoCoinId: cryptoTx.cryptoCoinId, cryptoAmount: cryptoTx.cryptoAmount,
                  fiatCurrency: fiatTx.cryptoCoinId.toUpperCase(),
                  fiatAmount: fiatTx.cryptoAmount.abs(),
                  // Aquí necesitamos una API para convertir COP a USD, por ahora asumimos una tasa.
                  // TODO: En el futuro, obtener la tasa histórica USD/COP para este cálculo.
                  usdValue: (fiatTx.cryptoCoinId.toUpperCase() == 'COP') ? fiatTx.cryptoAmount.abs() / 4000 : fiatTx.cryptoAmount.abs(),
                )
              );
            } 
            // La transacción cripto es negativa (venta) y la fiat es positiva (ingreso)
            else if (cryptoTx.cryptoAmount < 0 && fiatTx.cryptoAmount > 0) {
              processedTransactions.add(
                Transaction(
                  sourceAccount: cryptoTx.sourceAccount, type: 'Sell', date: cryptoTx.date,
                  wallet: cryptoTx.wallet, cryptoCoinId: cryptoTx.cryptoCoinId, cryptoAmount: cryptoTx.cryptoAmount,
                  fiatCurrency: fiatTx.cryptoCoinId.toUpperCase(),
                  fiatAmount: fiatTx.cryptoAmount.abs(),
                  usdValue: (fiatTx.cryptoCoinId.toUpperCase() == 'COP') ? fiatTx.cryptoAmount.abs() / 4000 : fiatTx.cryptoAmount.abs(),
                )
              );
            }
          }
          // Caso 2: CRIPTO_A <-> CRIPTO_B (Swap)
          else if (!txIsFiat && !pairTxIsFiat) {
              final txOut = tx.cryptoAmount < 0 ? tx : pairTx;
              final txIn = tx.cryptoAmount > 0 ? tx : pairTx;
              processedTransactions.add(Transaction(
                  sourceAccount: txOut.sourceAccount, type: 'Swap Out', date: txOut.date,
                  wallet: txOut.wallet, cryptoCoinId: txOut.cryptoCoinId, cryptoAmount: txOut.cryptoAmount,
              ));
              processedTransactions.add(Transaction(
                  sourceAccount: txIn.sourceAccount, type: 'Swap In', date: txIn.date,
                  wallet: txIn.wallet, cryptoCoinId: txIn.cryptoCoinId, cryptoAmount: txIn.cryptoAmount,
              ));
          }
        } else {
          convertPairs[tx.date] = tx;
        }
      } else {
        processedTransactions.add(tx);
      }
    }

    final Map<String, PortfolioAsset> portfolio = {};
    for (var tx in processedTransactions) {
      // ... (El resto de la lógica de cálculo de balances e inversión no necesita cambios)
      final coinId = tx.cryptoCoinId;

      portfolio.putIfAbsent(coinId, () {
        final marketInfo = marketPrices.firstWhere((c) => c.id == coinId, orElse: () => CryptoCoin(id: coinId, name: coinId.toUpperCase(), ticker: coinId.toUpperCase(), price: 0));
        return PortfolioAsset(coinId: coinId, name: marketInfo.name, ticker: marketInfo.ticker, balances: {});
      });

      final asset = portfolio[coinId]!;
      final totalAmountBeforeTx = asset.totalAmount;
      asset.balances.putIfAbsent(tx.wallet, () => 0.0);
      asset.balances[tx.wallet] = (asset.balances[tx.wallet] ?? 0.0) + tx.cryptoAmount;
      
      if (tx.type == 'Manual Buy' || tx.type == 'Buy') {
        asset.totalInvestedUSD += tx.usdValue ?? tx.fiatAmount ?? 0.0;
      } else if (tx.type == 'Manual Sell' || tx.type == 'Sell') {
        if (totalAmountBeforeTx > 0) {
          final percentageSold = tx.cryptoAmount.abs() / totalAmountBeforeTx;
          asset.totalInvestedUSD -= asset.totalInvestedUSD * percentageSold;
        }
      }
    }
    
    portfolio.removeWhere((key, asset) {
      if (asset.totalInvestedUSD.abs() < 0.001) asset.totalInvestedUSD = 0;
      asset.balances.removeWhere((wallet, amount) => amount.abs() < 0.00000001);
      return asset.balances.isEmpty || asset.totalAmount.abs() < 0.00000001;
    });
    
    portfolio.forEach((key, asset) {
      asset.averageBuyPrice = asset.totalAmount > 0 ? asset.totalInvestedUSD / asset.totalAmount : 0;
    });

    return portfolio.values.toList();
  }
  
  static PortfolioSummary calculateSummary({
    required List<PortfolioAsset> portfolio,
    required List<Transaction> allTransactions,
    required List<CryptoCoin> marketPrices,
    String? sourceAccount,
  }) {
    // ... (Esta función no necesita cambios, ya que depende de la salida de 'calculate')
    double currentPortfolioValue = 0, totalPortfolioInvested = 0;
    for (var asset in portfolio) {
      final marketCoin = marketPrices.firstWhere((c) => c.id == asset.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0.0));
      currentPortfolioValue += asset.totalAmount * marketCoin.price;
      totalPortfolioInvested += asset.totalInvestedUSD;
    }
    final transactionsToProcess = sourceAccount == null ? allTransactions : allTransactions.where((tx) => tx.sourceAccount == sourceAccount).toList();
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
    final recoveredInUSD = transactionsToProcess.where((tx) => tx.type == 'Manual Sell' || tx.type == 'Sell').fold<double>(0.0, (sum, tx) => sum + (tx.usdValue ?? tx.fiatAmount ?? 0.0));
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