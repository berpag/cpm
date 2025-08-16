// Versión 2.6
// lib/data/models/coin_models.dart

class CryptoCoin {
  final String id;
  final String name;
  final String ticker;
  final double price;
  // El campo 'totalInvestedUSD' ha sido eliminado de aquí.

  CryptoCoin({
    required this.id,
    required this.name,
    required this.ticker,
    required this.price,
  });
}

class PortfolioAsset {
  final String coinId;
  final String name;
  final String ticker;
  double? amount;
  double averageBuyPrice;
  // --- ¡AÑADIMOS EL NUEVO CAMPO AQUÍ! ---
  double totalInvestedUSD; 

  PortfolioAsset({
    required this.coinId,
    required this.name,
    required this.ticker,
    this.amount,
    required this.averageBuyPrice,
    // Lo hacemos requerido en el constructor.
    required this.totalInvestedUSD, 
  });
}

class Transaction {
  final String type;
  final DateTime date;
  final String? fiatCurrency;
  final double? fiatAmount;
  final String? cryptoCoinId;
  final double? cryptoAmount;
  final String? fromCoinId;
  final double? fromAmount;
  final String? toCoinId;
  final double? toAmount;

  Transaction({
    required this.type,
    required this.date,
    this.fiatCurrency,
    this.fiatAmount,
    this.cryptoCoinId,
    this.cryptoAmount,
    this.fromCoinId,
    this.fromAmount,
    this.toCoinId,
    this.toAmount,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'date': date.toIso8601String(),
      if (fiatCurrency != null) 'fiatCurrency': fiatCurrency,
      if (fiatAmount != null) 'fiatAmount': fiatAmount,
      if (cryptoCoinId != null) 'cryptoCoinId': cryptoCoinId,
      if (cryptoAmount != null) 'cryptoAmount': cryptoAmount,
      if (fromCoinId != null) 'fromCoinId': fromCoinId,
      if (fromAmount != null) 'fromAmount': fromAmount,
      if (toCoinId != null) 'toCoinId': toCoinId,
      if (toAmount != null) 'toAmount': toAmount,
    };
  }

  // --- ¡NUEVO CONSTRUCTOR PARA LEER DESDE FIRESTORE! ---
  factory Transaction.fromFirestore(Map<String, dynamic> data) {
    return Transaction(
      type: data['type'],
      date: DateTime.parse(data['date']),
      fiatCurrency: data['fiatCurrency'],
      fiatAmount: (data['fiatAmount'] as num?)?.toDouble(),
      cryptoCoinId: data['cryptoCoinId'],
      cryptoAmount: (data['cryptoAmount'] as num?)?.toDouble(),
      fromCoinId: data['fromCoinId'],
      fromAmount: (data['fromAmount'] as num?)?.toDouble(),
      toCoinId: data['toCoinId'],
      toAmount: (data['toAmount'] as num?)?.toDouble(),
    );
  }
}