// lib/presentation/screens/dashboard/widgets/portfolio_summary_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cpm/data/models/summary_models.dart'; // Asegúrate de que este import es correcto

class PortfolioSummaryCard extends StatelessWidget {
  // --- MODIFICADO: Ahora recibe el objeto completo ---
  final PortfolioSummary summary;

  const PortfolioSummaryCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final pnlColor = summary.totalPnlUSD >= 0 ? Colors.green : Colors.red;
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
            // --- MODIFICADO: Usa los valores del objeto summary ---
            _buildStatRow('Invertido Total:', formatCurrency.format(summary.totalInvested)),
            _buildStatRow('Valor Actual:', formatCurrency.format(summary.currentValue)),
            _buildStatRow('Recuperado por Ventas:', formatCurrency.format(summary.recoveredFromSales), isPositive: true),
            const Divider(height: 24, thickness: 1),
            _buildPnlRow('P/L Total:', summary.totalPnlUSD, summary.totalPnlPercent, pnlColor, formatCurrency),
          ],
        ),
      ),
    );
  }

  // Los widgets _buildStatRow y _buildPnlRow no necesitan cambios
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