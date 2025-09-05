// lib/data/utils/binance_parser.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';

class BinanceParser {
  static Future<List<Transaction>> parseAllRows(List<List<dynamic>> rows) async {
    final List<Transaction> transactions = [];
    final dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");

    for (var row in rows) {
      try {
        final wallet = row[2] as String;
        final operation = row[3] as String;
        
        // --- CAMBIO: YA NO IGNORAMOS LAS TRANSFERENCIAS ---

        final date = dateFormat.parse(row[1], true).toLocal();
        final coin = row[4] as String;
        final change = double.parse(row[5].toString());

        transactions.add(Transaction(
          sourceAccount: 'Binance',
          date: date, 
          wallet: wallet,
          type: operation,
          cryptoCoinId: _mapTickerToCoinId(coin),
          cryptoAmount: change,
        ));

      } catch (e) { /* Ignorar fila */ }
    }
    return transactions;
  }

  static String _mapTickerToCoinId(String ticker) {
    final map = {
      'USDT': 'tether', 'BTC': 'bitcoin', 'ETH': 'ethereum', 'BNB': 'binancecoin',
      'SOL': 'solana', 'XRP': 'ripple', 'DOGE': 'dogecoin', 'COP': 'colombian-peso',
      'NEAR': 'near', 'LINK': 'chainlink', 'RENDER': 'render-token', 'WIF': 'dogwifcoin',
      'XLM': 'stellar', 'ALGO': 'algorand', 'GRT': 'the-graph', 'PENDLE': 'pendle',
      'HBAR': 'hedera-hashgraph', 'PLUME': 'plume-network', 'LAYER': 'layer-protocol',
      'USDC': 'usd-coin', 'TREE': 'tree', 'TOWNS': 'town-star', 'PROVE': 'prove-token'
    };
    return map[ticker.toUpperCase()] ?? ticker.toLowerCase();
  }
}