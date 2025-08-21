// lib/presentation/screens/analysis/fiat_analysis_screen.dart

import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/models/summary_models.dart'; // Importamos el modelo de resumen
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:intl/intl.dart';

class FiatAnalysisScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const FiatAnalysisScreen({
    super.key,
    required this.transactions,
  });

  @override
  State<FiatAnalysisScreen> createState() => _FiatAnalysisScreenState();
}

class _FiatAnalysisScreenState extends State<FiatAnalysisScreen> {
  late PortfolioSummary summary;
  late List<Transaction> fiatTransactions;

  @override
  void initState() {
    super.initState();
    // Filtramos y ordenamos las transacciones una sola vez
    fiatTransactions = widget.transactions
        .where((tx) => tx.type == 'buy' || tx.type == 'sell')
        .toList();
    fiatTransactions.sort((a, b) => b.date.compareTo(a.date)); // Más reciente primero

    // Calculamos el resumen
    summary = PortfolioCalculator.calculateSummary(
      portfolio: [], // No necesitamos el portafolio para este cálculo
      transactions: widget.transactions,
      marketPrices: [], // No necesitamos precios de mercado aquí
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos la lista de todas las monedas fiat involucradas
    final fiatCurrencies = {...summary.totalInvestedByFiat.keys, ...summary.totalRecoveredByFiat.keys}.toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis de Flujo de Fiat'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          // --- SECCIÓN DE RESUMEN POR MONEDA ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Resumen por Moneda',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          fiatCurrencies.isEmpty
            ? const SliverFillRemaining(child: Center(child: Text('No hay transacciones con Fiat para analizar.')))
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final currency = fiatCurrencies[index];
                    final invested = summary.totalInvestedByFiat[currency] ?? 0.0;
                    final recovered = summary.totalRecoveredByFiat[currency] ?? 0.0;
                    final balance = recovered - invested;
                    
                    // Usamos un formateador específico para cada moneda si es necesario, o uno genérico
                    final formatCurrency = NumberFormat.currency(
                      locale: 'en_US', // Esto puede ser ajustado
                      symbol: '${currency.toUpperCase()} ',
                      decimalDigits: 2,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Flujo de ${currency.toUpperCase()}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 20),
                            _buildStatRow('Total Invertido:', formatCurrency.format(invested), Colors.red.shade700),
                            _buildStatRow('Total Recuperado:', formatCurrency.format(recovered), Colors.green.shade700),
                            const Divider(height: 20),
                            _buildStatRow('Balance Neto:', formatCurrency.format(balance), balance >= 0 ? Colors.green.shade700 : Colors.red.shade700),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: fiatCurrencies.length,
                ),
              ),

          // --- SECCIÓN DE HISTORIAL DETALLADO ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Historial de Transacciones Fiat',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final tx = fiatTransactions[index];
                final isBuy = tx.type == 'buy';
                
                final formatCurrency = NumberFormat.currency(
                  locale: 'en_US',
                  symbol: '${tx.fiatCurrency?.toUpperCase() ?? ''} ',
                  decimalDigits: 2,
                );

                return ListTile(
                  leading: Icon(
                    isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isBuy ? Colors.red : Colors.green,
                  ),
                  title: Text(
                    isBuy ? 'Compra' : 'Venta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(DateFormat('dd-MM-yyyy HH:mm').format(tx.date)),
                  trailing: Text(
                    formatCurrency.format(tx.fiatAmount),
                    style: TextStyle(
                      color: isBuy ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16
                    ),
                  ),
                );
              },
              childCount: fiatTransactions.length,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.black54)),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}