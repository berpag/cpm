// lib/data/models/coin_models.dart

class CryptoCoin {
  // ¡NUEVO! Añadimos el ID que nos da la API.
  final String id; 
  final String name;
  final String ticker;
  final double price;

  CryptoCoin({
    required this.id, // Requerimos el nuevo campo.
    required this.name,
    required this.ticker,
    required this.price,
  });
}

class PortfolioAsset {
  // ¡NUEVO! Añadimos el ID para saber a qué moneda del mercado corresponde.
  final String coinId; 
  final String name;
  final String ticker;
  final double amount;
  final double averageBuyPrice;

  PortfolioAsset({
    required this.coinId, // Requerimos el nuevo campo.
    required this.name,
    required this.ticker,
    required this.amount,
    required this.averageBuyPrice,
  });
}