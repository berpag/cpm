// lib/data/models/coin_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class CryptoCoin {
  final String id;
  final String name;
  final String ticker;
  final double price;
  final String? logoUrl;

  CryptoCoin({
    required this.id,
    required this.name,
    required this.ticker,
    required this.price,
    this.logoUrl,
  });
}

class PortfolioAsset {
  final String sourceAccount;
  final String coinId;
  String name;
  String ticker;
  final Map<String, double> balances;
  double totalInvestedUSD;
  double averageBuyPrice;
  // Campos opcionales para datos crudos, útiles en la UI
  final String? rawContract;
  final String? rawNetwork;

  PortfolioAsset({
    required this.sourceAccount,
    required this.coinId,
    required this.name,
    required this.ticker,
    required this.balances,
    this.totalInvestedUSD = 0.0,
    this.averageBuyPrice = 0.0,
    this.rawContract,
    this.rawNetwork,
  });

  double get totalAmount => balances.values.fold(0.0, (sum, amount) => sum + amount);

  PortfolioAsset copyWith({
    String? sourceAccount,
    String? coinId,
    String? name,
    String? ticker,
    Map<String, double>? balances,
    double? totalInvestedUSD,
    double? averageBuyPrice,
    String? rawContract,
    String? rawNetwork,
  }) {
    return PortfolioAsset(
      sourceAccount: sourceAccount ?? this.sourceAccount,
      coinId: coinId ?? this.coinId,
      name: name ?? this.name,
      ticker: ticker ?? this.ticker,
      balances: balances ?? this.balances,
      totalInvestedUSD: totalInvestedUSD ?? this.totalInvestedUSD,
      averageBuyPrice: averageBuyPrice ?? this.averageBuyPrice,
      rawContract: rawContract ?? this.rawContract,
      rawNetwork: rawNetwork ?? this.rawNetwork,
    );
  }
}

class Transaction {
  final String? id;
  final String sourceAccount;
  final String type;
  final DateTime date;
  final String wallet;
  final String cryptoCoinId;
  final double cryptoAmount;
  final String? fiatCurrency;
  final double? fiatAmount;
  final double? exchangeRateUsed;
  final double? usdValue;
  // --- NUEVOS CAMPOS ---
  final String? rawContract;
  final String? rawNetwork;

  Transaction({
    this.id,
    required this.sourceAccount,
    required this.type,
    required this.date,
    required this.wallet,
    required this.cryptoCoinId,
    required this.cryptoAmount,
    this.fiatCurrency,
    this.fiatAmount,
    this.exchangeRateUsed,
    this.usdValue,
    this.rawContract,
    this.rawNetwork,
  });

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      sourceAccount: data['sourceAccount'] ?? '',
      type: data['type'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      wallet: data['wallet'] ?? '',
      cryptoCoinId: data['cryptoCoinId'] ?? '',
      cryptoAmount: (data['cryptoAmount'] as num?)?.toDouble() ?? 0.0,
      fiatCurrency: data['fiatCurrency'],
      fiatAmount: (data['fiatAmount'] as num?)?.toDouble(),
      exchangeRateUsed: (data['exchangeRateUsed'] as num?)?.toDouble(),
      usdValue: (data['usdValue'] as num?)?.toDouble(),
      rawContract: data['rawContract'],
      rawNetwork: data['rawNetwork'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sourceAccount': sourceAccount,
      'type': type,
      'date': Timestamp.fromDate(date),
      'wallet': wallet,
      'cryptoCoinId': cryptoCoinId,
      'cryptoAmount': cryptoAmount,
      'fiatCurrency': fiatCurrency,
      'fiatAmount': fiatAmount,
      'exchangeRateUsed': exchangeRateUsed,
      'usdValue': usdValue,
      'rawContract': rawContract,
      'rawNetwork': rawNetwork,
    };
  }

  Transaction copyWith({
    String? id,
    String? sourceAccount,
    String? type,
    DateTime? date,
    String? wallet,
    String? cryptoCoinId,
    double? cryptoAmount,
    String? fiatCurrency,
    double? fiatAmount,
    double? exchangeRateUsed,
    double? usdValue,
    String? rawContract,
    String? rawNetwork,
  }) {
    return Transaction(
      id: id ?? this.id,
      sourceAccount: sourceAccount ?? this.sourceAccount,
      type: type ?? this.type,
      date: date ?? this.date,
      wallet: wallet ?? this.wallet,
      cryptoCoinId: cryptoCoinId ?? this.cryptoCoinId,
      cryptoAmount: cryptoAmount ?? this.cryptoAmount,
      fiatCurrency: fiatCurrency ?? this.fiatCurrency,
      fiatAmount: fiatAmount ?? this.fiatAmount,
      exchangeRateUsed: exchangeRateUsed ?? this.exchangeRateUsed,
      usdValue: usdValue ?? this.usdValue,
      rawContract: rawContract ?? this.rawContract,
      rawNetwork: rawNetwork ?? this.rawNetwork,
    );
  }
}