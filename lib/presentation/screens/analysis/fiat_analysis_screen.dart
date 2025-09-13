// lib/presentation/screens/analysis/fiat_analysis_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cpm/data/models/coin_models.dart' as app_models;

class FiatAnalysisScreen extends StatelessWidget {
  // --- PARÁMETROS ACTUALIZADOS ---
  final List<app_models.PortfolioAsset> fiatHoldings;
  final Map<String, double> totalInvestedByFiat;
  final Map<String, double> totalRecoveredByFiat;

  const FiatAnalysisScreen({
    super.key,
    required this.fiatHoldings,
    required this.totalInvestedByFiat,
    required this.totalRecoveredByFiat,
  });

  @override
  Widget build(BuildContext context) {
    // Creamos una lista de todos los tickers de fiat involucrados para no perder ninguno.
    final allFiatTickers = {
      ...totalInvestedByFiat.keys,
      ...totalRecoveredByFiat.keys
    }.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis de Fiat'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- SECCIÓN 1: BALANCES ACTUALES ---
          _buildSectionTitle(context, 'Balances Actuales en Fiat'),
          if (fiatHoldings.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Text('No tienes balances en monedas fiat.', style: TextStyle(color: Colors.grey)),
            ))
          else
            ...fiatHoldings.map((asset) => _buildBalanceCard(asset)),
          
          const Divider(height: 48, thickness: 1),

          // --- SECCIÓN 2: FLUJO TOTAL DE DINERO ---
          _buildSectionTitle(context, 'Flujo Total de Dinero Fiat'),
          if (allFiatTickers.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Text('No hay transacciones con fiat registradas.', style: TextStyle(color: Colors.grey)),
            ))
          else
            ...allFiatTickers.map((ticker) {
              final invested = totalInvestedByFiat[ticker] ?? 0.0;
              final recovered = totalRecoveredByFiat[ticker] ?? 0.0;
              final netFlow = recovered - invested;
              return _buildFlowCard(ticker, invested, recovered, netFlow);
            }),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBalanceCard(app_models.PortfolioAsset asset) {
    final formatNumber = NumberFormat('#,##0.00');
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          child: Text(asset.ticker.substring(0, 1)),
        ),
        title: Text(asset.ticker, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          formatNumber.format(asset.totalAmount),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildFlowCard(String ticker, double invested, double recovered, double netFlow) {
    final formatCurrency = NumberFormat.currency(locale: 'en_US', symbol: ''); // Sin símbolo para que sea genérico
    final netColor = netFlow >= 0 ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ticker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 16),
            _buildFlowRow('Total Invertido:', formatCurrency.format(invested), Colors.red.shade700),
            _buildFlowRow('Total Recuperado:', formatCurrency.format(recovered), Colors.green.shade800),
            _buildFlowRow('Flujo Neto:', formatCurrency.format(netFlow), netColor, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}