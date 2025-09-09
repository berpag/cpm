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


class Transaction {
  final String sourceAccount;
  final String type;
  final DateTime date;
  final String wallet;
  final String cryptoCoinId;
  final double cryptoAmount;
  final String? fiatCurrency;
  final double? fiatAmount;
  final double? exchangeRateUsed;

  // --- ¡NUEVO CAMPO PARA EL VALOR USD! ---
  final double? usdValue; // El valor de la transacción en USD, introducido por el usuario.

  Transaction({
    required this.sourceAccount,
    required this.type,
    required this.date,
    required this.wallet,
    required this.cryptoCoinId,
    required this.cryptoAmount,
    this.fiatCurrency,
    this.fiatAmount,
    this.exchangeRateUsed,
    this.usdValue, // --- Añadido al constructor ---
  });

  Map<String, dynamic> toFirestore() {
    return {
      'sourceAccount': sourceAccount,
      'type': type,
      'date': date.toIso8601String(),
      'wallet': wallet,
      'cryptoCoinId': cryptoCoinId,
      'cryptoAmount': cryptoAmount,
      if (fiatCurrency != null) 'fiatCurrency': fiatCurrency,
      if (fiatAmount != null) 'fiatAmount': fiatAmount,
      if (exchangeRateUsed != null) 'exchangeRateUsed': exchangeRateUsed,
      if (usdValue != null) 'usdValue': usdValue, // --- Añadido al mapa ---
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
      fiatCurrency: data['fiatCurrency'],
      fiatAmount: (data['fiatAmount'] as num?)?.toDouble(),
      exchangeRateUsed: (data['exchangeRateUsed'] as num?)?.toDouble(),
      usdValue: (data['usdValue'] as num?)?.toDouble(), // --- Leído del mapa ---
    );
  }
}