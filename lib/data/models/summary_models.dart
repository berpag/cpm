// lib/data/models/summary_models.dart

class PortfolioSummary {
  final double totalInvested;
  final double currentValue;
  final double totalPnlUSD;
  final double totalPnlPercent;
  final double recoveredFromSales;

  PortfolioSummary({
    required this.totalInvested,
    required this.currentValue,
    required this.totalPnlUSD,
    required this.totalPnlPercent,
    required this.recoveredFromSales,
  });
}