// lib/data/models/coin_models.dart

class CryptoCoin {
  final String id;
  final String name;
  final String ticker;
  final double price;

  CryptoCoin({required this.id, required this.name, required this.ticker, required this.price});
}

class PortfolioAsset {
  final String coinId;
  final String name;
  final String ticker;
  Map<String, double> balances; 
  double totalInvestedUSD;
  double averageBuyPrice;

  double get totalAmount => balances.values.fold(0.0, (sum, amount) => sum + amount);

  PortfolioAsset({
    required this.coinId,
    required this.name,
    required this.ticker,
    required this.balances,
    this.totalInvestedUSD = 0.0,
    this.averageBuyPrice = 0.0,
  });
}

// --- VERSIÓN COMPLETA Y FINAL DE TRANSACTION ---
class Transaction {
  final String sourceAccount;
  final String type; // La operación original del CSV
  final DateTime date;
  final String wallet;
  final String cryptoCoinId;
  final double cryptoAmount;

  Transaction({
    required this.sourceAccount,
    required this.type,
    required this.date,
    required this.wallet,
    required this.cryptoCoinId,
    required this.cryptoAmount,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'sourceAccount': sourceAccount,
      'type': type,
      'date': date.toIso8601String(),
      'wallet': wallet,
      'cryptoCoinId': cryptoCoinId,
      'cryptoAmount': cryptoAmount,
    };
  }

  factory Transaction.fromFirestore(Map<String, dynamic> data) {
    return Transaction(
      sourceAccount: data['sourceAccount'] ?? 'Manual',
      type: data['type'] ?? 'Unknown',
      date: DateTime.parse(data['date']),
      wallet: data['wallet'] ?? 'Spot',
      cryptoCoinId: data['cryptoCoinId'] ?? '',
      cryptoAmount: (data['cryptoAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}