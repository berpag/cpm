// lib/presentation/screens/account_detail/manual_account_detail_screen.dart

import 'package:flutter/material.dart';
import 'dart:async'; // Necesario para Future

import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/fiat_dialog_widget.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/swap_dialog_widget.dart';

class ManualAccountDetailScreen extends StatefulWidget {
  final List<app_models.CryptoCoin> marketPrices;

  const ManualAccountDetailScreen({
    super.key,
    required this.marketPrices,
  });

  @override
  State<ManualAccountDetailScreen> createState() => _ManualAccountDetailScreenState();
}

class _ManualAccountDetailScreenState extends State<ManualAccountDetailScreen> {
  bool _isProcessing = false;

  void _showFiatDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const FiatDialog());
  }

  void _showSwapDialog(List<app_models.PortfolioAsset> fullPortfolio) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => SwapDialog(myPortfolio: fullPortfolio));
  }

  // --- ¡NUEVA FUNCIÓN DE BORRADO AÑADIDA! ---
  Future<void> _showDeleteConfirmationDialog() async {
    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Estás seguro?'),
        content: const Text('Esta acción eliminará permanentemente TODAS tus transacciones manuales.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, estoy seguro')),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

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
      await FirestoreService.deleteTransactionsBySource('Manual');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todas las entradas manuales han sido eliminadas.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al borrar los datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Entradas Manuales'),
      ),
      body: StreamBuilder<List<app_models.Transaction>>(
        stream: FirestoreService.getTransactionsStream(),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTransactions = transactionSnapshot.data ?? [];

          return FutureBuilder<List<app_models.PortfolioAsset>>(
            future: PortfolioCalculator.calculate(
              allTransactions: allTransactions,
              marketPrices: widget.marketPrices,
              sourceAccount: 'Manual',
            ),
            builder: (context, manualPortfolioSnapshot) {
              if (manualPortfolioSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final manualAssets = manualPortfolioSnapshot.data ?? [];
              
              final fullPortfolioFuture = PortfolioCalculator.calculate(
                allTransactions: allTransactions,
                marketPrices: widget.marketPrices,
              );

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _isProcessing 
                          ? const Center(child: CircularProgressIndicator())
                          : Wrap(
                              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showFiatDialog,
                                  icon: const Icon(Icons.attach_money),
                                  label: const Text('Compra/Venta'),
                                ),
                                FutureBuilder<List<app_models.PortfolioAsset>>(
                                  future: fullPortfolioFuture,
                                  builder: (context, snapshot) {
                                    return ElevatedButton.icon(
                                      onPressed: snapshot.hasData ? () => _showSwapDialog(snapshot.data!) : null,
                                      icon: const Icon(Icons.swap_horiz),
                                      label: const Text('Swap'),
                                    );
                                  }
                                ),
                                // --- ¡BOTÓN DE BORRADO AÑADIDO! ---
                                ElevatedButton.icon(
                                  onPressed: _showDeleteConfirmationDialog,
                                  icon: const Icon(Icons.delete_forever),
                                  label: const Text('Borrar Manuales'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                                ),
                              ],
                            ),
                      ),
                    ),
                    
                    if (manualAssets.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: Text('No hay activos manuales.', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final asset = manualAssets[index];
                            final marketCoin = widget.marketPrices.firstWhere(
                              (coin) => coin.id == asset.coinId,
                              orElse: () => app_models.CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0),
                            );
                            return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
                          },
                          childCount: manualAssets.length,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}