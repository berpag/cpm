// lib/presentation/screens/account_detail/manual_account_detail_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/manual_cost_calculator.dart'; // <-- NUEVO IMPORT
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
  List<app_models.Transaction> _allTransactions = [];

  void _showFiatDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const FiatDialog());
  }

  void _showSwapDialog(List<app_models.PortfolioAsset> fullPortfolio) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => SwapDialog(myPortfolio: fullPortfolio));
  }

  Future<void> _showDeleteConfirmationDialog() async {
    // ... (El código de borrado no cambia)
    final bool? firstConfirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('¿Estás seguro?'), content: const Text('Esta acción eliminará permanentemente TODAS tus transacciones y datos calculados manuales.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, estoy seguro'))]));
    if (firstConfirm != true || !mounted) return;
    final bool? secondConfirm = await showDialog<bool>(context: context, barrierDismissible: false, builder: (context) { final controller = TextEditingController(); return StatefulBuilder(builder: (context, setState) { return AlertDialog(title: const Text('Confirmación Final'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Para confirmar, por favor escribe la palabra "borrar" en el campo de abajo.'), const SizedBox(height: 16), TextField(controller: controller, decoration: const InputDecoration(hintText: 'borrar'), autocorrect: false, textAlign: TextAlign.center, onChanged: (value) => setState(() {}))]), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: controller.text.trim().toLowerCase() == 'borrar' ? Colors.red : Colors.grey.shade400, foregroundColor: Colors.white), onPressed: controller.text.trim().toLowerCase() == 'borrar' ? () => Navigator.of(context).pop(true) : null, child: const Text('Borrar Definitivamente'))]); }); });
    if (secondConfirm != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await FirestoreService.deleteTransactionsBySource('Manual');
      await FirestoreService.deleteCalculatedDataBySource('Manual');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todas las entradas manuales han sido eliminadas.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al borrar los datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- ¡NUEVA FUNCIÓN DE CÁLCULO PARA MANUAL! ---
  Future<void> _calculateAveragePrices() async {
    setState(() => _isProcessing = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iniciando cálculo de precios promedio manuales...')));

    try {
      final manualPortfolio = await PortfolioCalculator.calculate(
        allTransactions: _allTransactions,
        marketPrices: widget.marketPrices,
        sourceAccount: 'Manual',
      );
      if (manualPortfolio.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay activos manuales para calcular.')));
        setState(() => _isProcessing = false);
        return;
      }

      final manualTransactions = _allTransactions.where((tx) => tx.sourceAccount == 'Manual').toList();

      for (final asset in manualPortfolio) {
        final result = await ManualCostCalculator.calculateWeightedAveragePrice(
          assetIdToCalculate: asset.coinId,
          allManualTransactions: manualTransactions,
        );
        
        await FirestoreService.updateCalculatedAssetData(
          sourceAccount: 'Manual', 
          assetId: asset.coinId, 
          dataToUpdate: result,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Cálculo de precios manuales completado!'), backgroundColor: Colors.green));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en el cálculo: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  
  // --- ¡NUEVA FUNCIÓN PARA EDITAR PRECIO! ---
  Future<void> _showEditPriceDialog(app_models.PortfolioAsset asset) async {
    // ... (Esta función es idéntica a la de la pantalla de Binance)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Entradas Manuales')),
      body: StreamBuilder<List<app_models.Transaction>>(
        stream: FirestoreService.getTransactionsStream(),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          _allTransactions = transactionSnapshot.data ?? [];

          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: FirestoreService.getCalculatedPortfolioStream(),
            builder: (context, calculatedDataSnapshot) {
              if (calculatedDataSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final calculatedData = calculatedDataSnapshot.data ?? {};

              return FutureBuilder<List<app_models.PortfolioAsset>>(
                future: PortfolioCalculator.calculate(allTransactions: _allTransactions, marketPrices: widget.marketPrices, sourceAccount: 'Manual'),
                builder: (context, manualPortfolioSnapshot) {
                  if (manualPortfolioSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final manualAssets = manualPortfolioSnapshot.data ?? [];
                  for (var asset in manualAssets) {
                    final docId = 'Manual_${asset.coinId}';
                    if (calculatedData.containsKey(docId)) {
                      asset.averageBuyPrice = (calculatedData[docId]!['averageBuyPrice'] as num?)?.toDouble() ?? 0.0;
                      asset.totalInvestedUSD = (calculatedData[docId]!['totalInvestedUSD'] as num?)?.toDouble() ?? 0.0;
                    }
                  }
                  
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
                                    ElevatedButton.icon(onPressed: _showFiatDialog, icon: const Icon(Icons.attach_money), label: const Text('Compra/Venta')),
                                    ElevatedButton.icon(onPressed: () => _showSwapDialog(manualAssets), icon: const Icon(Icons.swap_horiz), label: const Text('Swap')),
                                    // --- ¡NUEVO BOTÓN DE CÁLCULO! ---
                                    ElevatedButton.icon(
                                      onPressed: _calculateAveragePrices,
                                      icon: const Icon(Icons.price_change_outlined),
                                      label: const Text('Calcular Precios'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                                    ),
                                    ElevatedButton.icon(onPressed: _showDeleteConfirmationDialog, icon: const Icon(Icons.delete_forever), label: const Text('Borrar Manuales'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white)),
                                  ],
                                ),
                          ),
                        ),
                        
                        if (manualAssets.isEmpty)
                          const SliverFillRemaining(child: Center(child: Text('No hay activos manuales.', style: TextStyle(color: Colors.grey))))
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final asset = manualAssets[index];
                                final marketCoin = widget.marketPrices.firstWhere((coin) => coin.id == asset.coinId, orElse: () => app_models.CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0));
                                return CryptoCoinCard(asset: asset, marketCoin: marketCoin, onEdit: () => _showEditPriceDialog(asset));
                              },
                              childCount: manualAssets.length,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            }
          );
        },
      ),
    );
  }
}