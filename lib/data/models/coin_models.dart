// Versión 1.5
// lib/data/models/coin_models.dart

class CryptoCoin {
  final String id;
  final String name;
  final String ticker;
  final double price;

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
  // ¡CAMBIO! La cantidad ahora puede ser nula.
  double? amount;
  final double averageBuyPrice;

  PortfolioAsset({
    required this.coinId,
    required this.name,
    required this.ticker,
    this.amount,
    required this.averageBuyPrice,
  });
}