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
        
        if (operation == 'Transfer Between Main and Funding Wallet') {
          continue;
        }

        final date = dateFormat.parse(row[1], true).toLocal();
        final coinTicker = row[4] as String;
        final change = double.parse(row[5].toString());

        transactions.add(Transaction(
          sourceAccount: 'Binance',
          date: date, 
          wallet: wallet,
          type: operation,
          // --- LÓGICA SIMPLIFICADA DIRECTAMENTE AQUÍ ---
          cryptoCoinId: coinTicker.toLowerCase(),
          cryptoAmount: change,
        ));

      } catch (e) { /* Ignorar fila */ }
    }
    return transactions;
  }
}