// lib/data/utils/binance_parser.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';

class BinanceParser {
  static Future<List<Transaction>> parseAllRows(List<List<dynamic>> rows) async {
    final List<Transaction> transactions = [];
    // Mantenemos el formato para parsear la fecha del CSV
    final dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");

    for (var row in rows) {
      try {
        final dateString = row[1].toString();
        final wallet = row[2] as String;
        final operation = row[3] as String;
        
        if (operation == 'Transfer Between Main and Funding Wallet') {
          continue;
        }

        // --- CORRECCIÓN CLAVE ---
        // 1. Parseamos el texto de la fecha. El 'true' indica que es UTC.
        final date = dateFormat.parse(dateString, true); 
        // 2. No usamos .toLocal(). Mantenemos el objeto DateTime como UTC.
        //    Firestore se encargará de manejar las zonas horarias.
        // --- FIN DE LA CORRECCIÓN ---

        final coinTicker = row[4] as String;
        final change = double.parse(row[5].toString());

        transactions.add(Transaction(
          sourceAccount: 'Binance',
          date: date, // Pasamos el objeto DateTime UTC.
          wallet: wallet,
          type: operation,
          cryptoCoinId: coinTicker.toLowerCase(),
          cryptoAmount: change,
        ));

      } catch (e) {
        print('Error parseando fila de Binance: $row. Error: $e');
        // Ignorar fila para evitar que un error detenga toda la importación.
      }
    }
    return transactions;
  }
}