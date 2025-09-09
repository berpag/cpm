// lib/presentation/screens/account_detail/account_detail_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/csv_importer.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/binance_parser.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';

class AccountDetailScreen extends StatefulWidget {
  final String accountName;
  final List<CryptoCoin> marketPrices;

  const AccountDetailScreen({
    super.key, 
    required this.accountName,
    required this.marketPrices,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  bool _isImporting = false;

  Future<void> _importTransactions() async {
    setState(() => _isImporting = true);
    try {
      final rows = await CsvImporter.importAndParseCsv();
      if (rows.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se importaron transacciones.')));
        setState(() => _isImporting = false);
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
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Estás seguro?'),
        content: const Text('Esta acción eliminará permanentemente TODAS tus transacciones. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Sí, estoy seguro'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Confirmación Final'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Para confirmar, por favor escribe la palabra "borrar" en el campo de abajo.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'borrar'),
                    autocorrect: false,
                    textAlign: TextAlign.center,
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: controller.text.trim().toLowerCase() == 'borrar' 
                        ? Colors.red 
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: controller.text.trim().toLowerCase() == 'borrar'
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('Borrar Definitivamente'),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (secondConfirm != true) return;

    if (mounted) setState(() => _isImporting = true);
    try {
      await FirestoreService.deleteAllUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos los datos han sido eliminados.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al borrar los datos: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle de ${widget.accountName}'),
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: FirestoreService.getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTransactions = snapshot.data ?? [];
          final fullPortfolio = PortfolioCalculator.calculate(
            allTransactions, widget.marketPrices, sourceAccount: widget.accountName,
          );
          
          final spotAssets = <PortfolioAsset>[];
          final earnAssets = <PortfolioAsset>[];

          for (var asset in fullPortfolio) {
            final spotVersion = PortfolioAsset(coinId: asset.coinId, name: asset.name, ticker: asset.ticker, balances: {});
            final earnVersion = PortfolioAsset(coinId: asset.coinId, name: asset.name, ticker: asset.ticker, balances: {});
            
            asset.balances.forEach((wallet, amount) {
              if (amount.abs() > 0.00000001) {
                if (wallet.contains('Earn')) {
                  earnVersion.balances[wallet] = amount;
                } else {
                  spotVersion.balances[wallet] = amount;
                }
              }
            });

            if (spotVersion.totalAmount > 0) spotAssets.add(spotVersion);
            if (earnVersion.totalAmount > 0) earnAssets.add(earnVersion);
          }

          return RefreshIndicator(
              onRefresh: () async {},
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _isImporting 
                        ? const Center(child: CircularProgressIndicator())
                        : Wrap(
                            spacing: 16, runSpacing: 8, alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _importTransactions,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Importar Transacciones (CSV)'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _showDeleteConfirmationDialog,
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Borrar Todos los Datos'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                              ),
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
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(top: 24.0),
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }

  Widget _buildAssetList(List<PortfolioAsset> assets) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final asset = assets[index];
          final marketCoin = widget.marketPrices.firstWhere(
            (c) => c.id == asset.coinId, 
            orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0)
          );
          return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
        },
        childCount: assets.length,
      ),
    );
  }

  Widget _buildEmptySection() {
    return const SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No hay activos en esta billetera.', style: TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }
}