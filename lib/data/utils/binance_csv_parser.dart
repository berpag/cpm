// lib/data/utils/binance_csv_parser.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

// Parser simplificado: solo procesa operaciones que no son de trading.
class BinanceCsvParser {
  static final Map<String, String> _coinIdCache = {};

  static Future<List<Transaction>> parse(String csvContent) async {
    final List<Transaction> transactions = [];
    final marketCoins = await ApiService.getCoins();
    final converter = CsvToListConverter(fieldDelimiter: ',', eol: '\n');
    final List<List<dynamic>> rows = converter.convert(csvContent);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final operation = row[3].toString();

      // IGNORAMOS los trades, ya que los obtenemos de la API
      if (operation.startsWith('Transaction')) {
        continue;
      }

      try {
        final date = DateFormat('yyyy-MM-dd HH:mm:ss').parse(row[1].toString(), true).toUtc();
        Transaction? newTx;
        
        // Aquí podríamos añadir lógica para 'Small Assets Exchange' y otras operaciones si fuera necesario.
        // Por ahora, nos centramos en los movimientos de fondos.
        if (operation == 'Deposit' || operation == 'Withdraw' || operation == 'P2P Trading' || operation.contains('Reward') || operation.contains('Airdrop') || operation.contains('Earn')) {
            newTx = await _processSingleRowOperation(row, date, marketCoins);
        }
        
        if (newTx != null) {
          transactions.add(newTx);
        }
      } catch (e) {
        // Ignorar errores de parseo para filas no relevantes
      }
    }
    return transactions;
  }
  
  static double _getAmount(dynamic rawAmount) => double.parse(rawAmount.toString());

  static Future<Transaction?> _processSingleRowOperation(List<dynamic> row, DateTime date, List<CryptoCoin> marketCoins) async {
    final ticker = row[4].toString();
    final amount = _getAmount(row[5]);
    
    if (ticker == 'COP') {
      return Transaction(
        type: amount >= 0 ? 'DEPOSIT' : 'WITHDRAW',
        date: date,
        fiatCurrency: 'COP',
        fiatAmount: amount.abs(),
        exchangeTradeId: 'binance_csv_fiat_${date.millisecondsSinceEpoch}_$ticker',
      );
    }

    final coinId = await _getCoinId(ticker, marketCoins);
    if (coinId == null) return null;

    return Transaction(
      type: amount >= 0 ? 'TRANSFER_IN' : 'TRANSFER_OUT',
      date: date,
      cryptoCoinId: coinId,
      cryptoAmount: amount.abs(),
      exchangeTradeId: 'binance_csv_crypto_${date.millisecondsSinceEpoch}_$ticker',
    );
  }

  static Future<String?> _getCoinId(String ticker, List<CryptoCoin> marketPrices) async {
    try {
      if (_coinIdCache.containsKey(ticker)) return _coinIdCache[ticker];
      final coin = marketPrices.firstWhere((c) => c.ticker == ticker.toUpperCase());
      _coinIdCache[ticker] = coin.id;
      return coin.id;
    } catch (e) {
      return null;
    }
  }
}