// lib/data/utils/transaction_converter.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/binance_api_service.dart';
import 'package:cpm/data/services/api_service.dart'; 

class TransactionConverter {
  // --- FUNCIÓN ACTUALIZADA PARA DEVOLVER UNA LISTA DE TRANSACCIONES ---
  static Future<List<Transaction>> fromBinanceTrade(BinanceTrade trade, List<CryptoCoin> marketPrices) async {
    final List<Transaction> transactions = [];
    const quoteCurrencies = {'USDT', 'USDC', 'BUSD', 'TUSD', 'FDUSD', 'TRY', 'EUR', 'GBP'};
    
    String? baseAssetTicker, quoteAssetTicker;

    for (var quote in quoteCurrencies) {
      if (trade.symbol.endsWith(quote)) {
        baseAssetTicker = trade.symbol.replaceAll(quote, '');
        quoteAssetTicker = quote;
        break;
      }
    }
    if(baseAssetTicker == null) {
      if(trade.symbol.endsWith('BTC')) { baseAssetTicker = trade.symbol.replaceAll('BTC', ''); quoteAssetTicker = 'BTC'; } 
      else if (trade.symbol.endsWith('ETH')) { baseAssetTicker = trade.symbol.replaceAll('ETH', ''); quoteAssetTicker = 'ETH'; }
    }

    if (baseAssetTicker == null || quoteAssetTicker == null) return [];
    
    try {
      final baseCoinInfo = await _findCoinInfo(baseAssetTicker, marketPrices);
      final quoteCoinInfo = await _findCoinInfo(quoteAssetTicker, marketPrices);
      
      Transaction mainTransaction;

      if (quoteCurrencies.contains(quoteAssetTicker)) { // Es compra/venta vs fiat/stable
        mainTransaction = Transaction(
          type: trade.isBuyer ? 'BUY' : 'SELL',
          date: DateTime.fromMillisecondsSinceEpoch(trade.time),
          cryptoCoinId: baseCoinInfo.id,
          cryptoAmount: trade.qty,
          fiatCurrency: quoteAssetTicker,
          fiatAmount: trade.quoteQty,
          fiatAmountInUSD: trade.quoteQty, // Asumimos 1:1 con USD
          exchangeTradeId: 'binance_${trade.id}',
        );
      } else { // Es un swap crypto/crypto
        mainTransaction = Transaction(
          type: 'SWAP',
          date: DateTime.fromMillisecondsSinceEpoch(trade.time),
          fromCoinId: trade.isBuyer ? quoteCoinInfo.id : baseCoinInfo.id,
          fromAmount: trade.isBuyer ? trade.quoteQty : trade.qty,
          toCoinId: trade.isBuyer ? baseCoinInfo.id : quoteCoinInfo.id,
          toAmount: trade.isBuyer ? trade.qty : trade.quoteQty,
          exchangeTradeId: 'binance_${trade.id}',
        );
      }
      transactions.add(mainTransaction);

      // --- ¡NUEVA LÓGICA DE COMISIONES! ---
      if (trade.commission > 0) {
        final commissionCoinInfo = await _findCoinInfo(trade.commissionAsset, marketPrices);
        final commissionTransaction = Transaction(
          type: 'FEE',
          date: DateTime.fromMillisecondsSinceEpoch(trade.time),
          cryptoCoinId: commissionCoinInfo.id,
          cryptoAmount: trade.commission,
          // Vinculamos la comisión al trade original
          exchangeTradeId: 'binance_${trade.id}_fee', 
        );
        transactions.add(commissionTransaction);
      }

      return transactions;
    } catch (e) {
      print("[Converter] Error al procesar el trade ${trade.symbol}: $e");
      return [];
    }
  }

  // Helper para buscar info de moneda, refactorizado
  static Future<CryptoCoin> _findCoinInfo(String ticker, List<CryptoCoin> marketPrices) async {
    try {
      return marketPrices.firstWhere((c) => c.ticker == ticker);
    } catch (e) {
      print("[Converter] Moneda '$ticker' no encontrada localmente, buscando en API...");
      final searchResults = await ApiService.searchCoins(ticker);
      final matchedCoin = searchResults.firstWhere((c) => c.ticker == ticker, orElse: () => CryptoCoin(id: ticker.toLowerCase(), name: ticker, ticker: ticker, price: 0));
      if(!marketPrices.any((c) => c.id == matchedCoin.id)) {
        marketPrices.add(matchedCoin);
      }
      return matchedCoin;
    }
  }
}