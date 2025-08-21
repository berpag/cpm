// lib/data/models/summary_models.dart

class PortfolioSummary {
  final double totalInvested;
  final double currentValue;
  final double totalPnlUSD;
  final double totalPnlPercent;
  final double recoveredFromSales;

  // --- ¡NUEVOS CAMPOS! ---
  // Un mapa donde la clave es el código de la moneda (ej. "cop") y el valor es el monto total.
  final Map<String, double> totalInvestedByFiat;
  final Map<String, double> totalRecoveredByFiat;

  PortfolioSummary({
    required this.totalInvested,
    required this.currentValue,
    required this.totalPnlUSD,
    required this.totalPnlPercent,
    required this.recoveredFromSales,
    // --- Añadidos al constructor ---
    required this.totalInvestedByFiat,
    required this.totalRecoveredByFiat,
  });
}

// La clase HistoricalData no cambia
class HistoricalData {
  final double cryptoPriceInUSD;
  final double? fiatExchangeRate;

  HistoricalData({required this.cryptoPriceInUSD, this.fiatExchangeRate});
}