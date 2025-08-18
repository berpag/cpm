// lib/presentation/screens/dashboard/widgets/portfolio_summary_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PortfolioSummaryCard extends StatelessWidget {
  final double totalInvested;
  final double currentValue;
  final double totalPnlUSD;
  final double totalPnlPercent;
  final double recoveredFromSales;

  const PortfolioSummaryCard({
    super.key,
    required this.totalInvested,
    required this.currentValue,
    required this.totalPnlUSD,
    required this.totalPnlPercent,
    required this.recoveredFromSales,
  });

  @override
  Widget build(BuildContext context) {
    final pnlColor = totalPnlUSD >= 0 ? Colors.green : Colors.red;
    final formatCurrency = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumen del Portafolio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildStatRow('Invertido Total:', formatCurrency.format(totalInvested)),
            _buildStatRow('Valor Actual:', formatCurrency.format(currentValue)),
            _buildStatRow('Recuperado por Ventas:', formatCurrency.format(recoveredFromSales), isPositive: true),
            const Divider(height: 24, thickness: 1),
            _buildPnlRow('P/L Total:', totalPnlUSD, totalPnlPercent, pnlColor, formatCurrency),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {bool isPositive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.blue.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnlRow(String label, double pnlUSD, double pnlPercent, Color color, NumberFormat formatter) {
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
               Text(
                formatter.format(pnlUSD),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                '${pnlPercent.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          )
        ],
      ),
    );
  }
}