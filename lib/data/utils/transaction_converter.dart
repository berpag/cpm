// lib/data/utils/transaction_converter.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/binance_api_service.dart';
// ¡Importamos el ApiService de CoinGecko!
import 'package:cpm/data/services/api_service.dart'; 

class TransactionConverter {
  // --- FUNCIÓN CONVERTIDA A ASÍNCRONA ---
  static Future<Transaction?> fromBinanceTrade(BinanceTrade trade, List<CryptoCoin> marketPrices) async {
    // Definimos las monedas de cotización que trataremos como "fiat"
    const quoteCurrencies = {'USDT', 'USDC', 'BUSD', 'TUSD', 'FDUSD', 'TRY', 'EUR', 'GBP'};
    
    String? baseAssetTicker;
    String? quoteAssetTicker;

    // Lógica para separar el símbolo. Ej: "BTCUSDT" -> "BTC" y "USDT"
    for (var quote in quoteCurrencies) {
      if (trade.symbol.endsWith(quote)) {
        baseAssetTicker = trade.symbol.replaceAll(quote, '');
        quoteAssetTicker = quote;
        break;
      }
    }
    // Si no es un par contra una moneda fiat/stable, intentamos con BTC o ETH
    if(baseAssetTicker == null) {
      if(trade.symbol.endsWith('BTC')) {
        baseAssetTicker = trade.symbol.replaceAll('BTC', '');
        quoteAssetTicker = 'BTC';
      } else if (trade.symbol.endsWith('ETH')) {
        baseAssetTicker = trade.symbol.replaceAll('ETH', '');
        quoteAssetTicker = 'ETH';
      }
    }

    if (baseAssetTicker == null || quoteAssetTicker == null) {
      print("[Converter] ADVERTENCIA: Par no soportado o no reconocido: ${trade.symbol}");
      return null;
    }
    
    // --- LÓGICA INTELIGENTE PARA ENCONTRAR/BUSCAR LA CRIPTO ---
    try {
      // Función interna para buscar la info de una moneda
      Future<CryptoCoin> findCoinInfo(String ticker) async {
        // 1. Busca en la lista de precios que ya tenemos
        final existingCoin = marketPrices.firstWhere((c) => c.ticker == ticker, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0));
        if (existingCoin.id.isNotEmpty) {
          return existingCoin;
        }
        // 2. Si no la encuentra, la busca en CoinGecko por su ticker
        print("[Converter] Moneda '$ticker' no encontrada localmente, buscando en CoinGecko...");
        final searchResults = await ApiService.searchCoins(ticker);
        final matchedCoin = searchResults.firstWhere((c) => c.ticker == ticker, orElse: () => CryptoCoin(id: ticker.toLowerCase(), name: ticker, ticker: ticker, price: 0));
        // Añadimos la nueva moneda a la lista para no volver a buscarla
        if(!marketPrices.any((c) => c.id == matchedCoin.id)) {
          marketPrices.add(matchedCoin);
        }
        return matchedCoin;
      }
      
      // Obtenemos la info de ambas monedas del par
      final baseCoinInfo = await findCoinInfo(baseAssetTicker);
      final quoteCoinInfo = await findCoinInfo(quoteAssetTicker);
      
      double fiatAmount = 0.0;
      double fiatAmountInUSD = 0.0;
      String fiatCurrency = '';
      
      // Determinamos qué tipo de transacción es (compra/venta fiat o swap)
      if (quoteCurrencies.contains(quoteAssetTicker)) {
        // Es una compra/venta contra una moneda fiat/stable
        fiatAmount = trade.quoteQty;
        fiatAmountInUSD = trade.quoteQty; // Asumimos 1:1 con USD para stables
        fiatCurrency = quoteAssetTicker;
        
        return Transaction(
          type: trade.isBuyer ? 'buy' : 'sell',
          date: DateTime.fromMillisecondsSinceEpoch(trade.time),
          cryptoCoinId: baseCoinInfo.id,
          cryptoAmount: trade.qty,
          fiatCurrency: fiatCurrency,
          fiatAmount: fiatAmount,
          fiatAmountInUSD: fiatAmountInUSD, 
          exchangeTradeId: 'binance_${trade.id}',
        );

      } else {
        // Es un swap entre dos criptomonedas (ej. ETH/BTC)
        return Transaction(
          type: 'swap',
          date: DateTime.fromMillisecondsSinceEpoch(trade.time),
          fromCoinId: trade.isBuyer ? quoteCoinInfo.id : baseCoinInfo.id,
          fromAmount: trade.isBuyer ? trade.quoteQty : trade.qty,
          toCoinId: trade.isBuyer ? baseCoinInfo.id : quoteCoinInfo.id,
          toAmount: trade.isBuyer ? trade.qty : trade.quoteQty,
          exchangeTradeId: 'binance_${trade.id}',
        );
      }
    } catch (e) {
      print("[Converter] Error al procesar el trade ${trade.symbol}: $e");
      return null;
    }
  }
}