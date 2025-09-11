// lib/presentation/screens/account_detail/binance_detail_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/csv_importer.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/binance_parser.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';

class BinanceDetailScreen extends StatefulWidget {
  final String accountName;
  final List<CryptoCoin> marketPrices;

  const BinanceDetailScreen({
    super.key, 
    required this.accountName,
    required this.marketPrices,
  });

  @override
  State<BinanceDetailScreen> createState() => _BinanceDetailScreenState();
}

class _BinanceDetailScreenState extends State<BinanceDetailScreen> {
  bool _isProcessing = false;

  Future<void> _importTransactions() async {
    setState(() => _isProcessing = true);
    try {
      final rows = await CsvImporter.importAndParseCsv();
      if (rows.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se importaron transacciones.')));
        setState(() => _isProcessing = false);
        return;
      }
      
      final transactions = await BinanceParser.parseAllRows(rows);
      await FirestoreService.addTransactionsInBatch(transactions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡${transactions.length} transacciones importadas!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- ¡FUNCIÓN DE BORRADO ACTUALIZADA! ---
  Future<void> _showDeleteConfirmationDialog() async {
    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Estás seguro?'),
        // Texto específico
        content: Text('Esta acción eliminará permanentemente TODAS tus transacciones de ${widget.accountName}. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, estoy seguro')),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // El segundo diálogo de confirmación con la palabra "borrar" no necesita cambios.
    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirmación Final'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Para confirmar, por favor escribe la palabra "borrar" en el campo de abajo.'),
                const SizedBox(height: 16),
                TextField(controller: controller, decoration: const InputDecoration(hintText: 'borrar'), autocorrect: false, textAlign: TextAlign.center, onChanged: (value) => setState(() {})),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: controller.text.trim().toLowerCase() == 'borrar' ? Colors.red : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: controller.text.trim().toLowerCase() == 'borrar' ? () => Navigator.of(context).pop(true) : null,
                  child: const Text('Borrar Definitivamente'),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (secondConfirm != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      // --- Llamada a la nueva función de borrado por fuente ---
      await FirestoreService.deleteTransactionsBySource(widget.accountName);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Todos los datos de ${widget.accountName} han sido eliminados.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al borrar los datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalle de ${widget.accountName}')),
      body: StreamBuilder<List<Transaction>>(
        stream: FirestoreService.getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allTransactions = snapshot.data ?? [];
          return FutureBuilder<List<PortfolioAsset>>(
            future: PortfolioCalculator.calculate(
              allTransactions: allTransactions,
              marketPrices: widget.marketPrices,
              sourceAccount: widget.accountName,
            ),
            builder: (context, portfolioSnapshot) {
              if (portfolioSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (portfolioSnapshot.hasError) {
                return Center(child: Text('Error al calcular portafolio: ${portfolioSnapshot.error}'));
              }

              final fullPortfolio = portfolioSnapshot.data ?? [];
              final spotAssets = <PortfolioAsset>[];
              final earnAssets = <PortfolioAsset>[];

              for (var asset in fullPortfolio) {
                final spotVersion = PortfolioAsset(sourceAccount: asset.sourceAccount, coinId: asset.coinId, name: asset.name, ticker: asset.ticker, balances: {});
                final earnVersion = PortfolioAsset(sourceAccount: asset.sourceAccount, coinId: asset.coinId, name: asset.name, ticker: asset.ticker, balances: {});
                asset.balances.forEach((wallet, amount) {
                  if (amount.abs() > 1e-8) {
                    if (wallet.contains('Earn')) earnVersion.balances[wallet] = amount;
                    else spotVersion.balances[wallet] = amount;
                  }
                });
                if (spotVersion.totalAmount > 0) spotAssets.add(spotVersion);
                if (earnVersion.totalAmount > 0) earnAssets.add(earnVersion);
              }

              return RefreshIndicator(
                onRefresh: () async => setState((){}),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _isProcessing ? const Center(child: CircularProgressIndicator()) : Wrap(
                          spacing: 16, runSpacing: 8, alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(onPressed: _importTransactions, icon: const Icon(Icons.upload_file), label: const Text('Importar Transacciones (CSV)')),
                            // Texto del botón actualizado
                            ElevatedButton.icon(onPressed: _showDeleteConfirmationDialog, icon: const Icon(Icons.delete_forever), label: Text('Borrar Datos de ${widget.accountName}'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    _buildSectionHeader('Spot'),
                    if (spotAssets.isEmpty) _buildEmptySection() else _buildAssetList(spotAssets),
                    _buildSectionHeader('Earn'),
                    if (earnAssets.isEmpty) _buildEmptySection() else _buildAssetList(earnAssets),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(top: 24.0), child: Text(title, style: Theme.of(context).textTheme.headlineSmall)));
  }

  Widget _buildAssetList(List<PortfolioAsset> assets) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final asset = assets[index];
          final marketCoin = widget.marketPrices.firstWhere((c) => c.id == asset.coinId, orElse: () => CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0));
          return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
        },
        childCount: assets.length,
      ),
    );
  }

  Widget _buildEmptySection() {
    return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No hay activos en esta billetera.', style: TextStyle(color: Colors.grey)))));
  }
}