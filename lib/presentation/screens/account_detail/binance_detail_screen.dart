// lib/presentation/screens/account_detail/binance_detail_screen.dart

import 'dart:async';
import 'package:cpm/data/services/secure_storage_service.dart';
import 'package:cpm/presentation/screens/connections/widgets/api_key_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/csv_importer.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/binance_cost_calculator.dart'; 
import 'package:cpm/data/utils/binance_parser.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/data/services/binance_api_service.dart';
import 'package:intl/intl.dart';

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
  List<Transaction> _allTransactions = [];
  bool _apiKeysExist = false;

  @override
  void initState() {
    super.initState();
    _checkApiKeys();
  }

  Future<void> _checkApiKeys() async {
    final apiKey = await SecureStorageService.getApiKey(widget.accountName);
    if (mounted) {
      setState(() {
        _apiKeysExist = (apiKey != null && apiKey.isNotEmpty);
      });
    }
  }

  Future<void> _importTransactions() async {
    setState(() => _isProcessing = true);
    try {
      final importResult = await CsvImporter.importAndParseCsv();
      if (importResult == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se importaron transacciones.')));
        setState(() => _isProcessing = false);
        return;
      }
      final List<List<dynamic>> rows = importResult['rows'];
      final String csvContent = importResult['content'];
      await FirestoreService.saveRawCsvData(sourceAccount: widget.accountName, csvContent: csvContent);
      final transactions = await BinanceParser.parseAllRows(rows);
      await FirestoreService.deleteTransactionsBySource(widget.accountName);
      await FirestoreService.addTransactionsInBatch(transactions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡${transactions.length} transacciones importadas y CSV guardado!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleApiConnection() async {
    if (_apiKeysExist) {
      await SecureStorageService.deleteKeys(widget.accountName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claves API desconectadas.'), backgroundColor: Colors.orange));
        _checkApiKeys();
      }
      return;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => ApiKeyDialog(exchangeName: widget.accountName),
    );

    if (result == null || !mounted) return;

    final apiKey = result['apiKey']!;
    final secretKey = result['secretKey']!;

    setState(() => _isProcessing = true);
    try {
      await BinanceApiService.getAccountInfo(apiKey: apiKey, secretKey: secretKey);
      await SecureStorageService.saveApiKey(widget.accountName, apiKey);
      await SecureStorageService.saveSecretKey(widget.accountName, secretKey);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡API conectada con éxito!'), backgroundColor: Colors.green));
        _checkApiKeys();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al conectar API: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final bool? firstConfirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('¿Estás seguro?'), content: Text('Esta acción eliminará permanentemente TODAS tus transacciones y datos calculados de ${widget.accountName}.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, estoy seguro'))]));
    if (firstConfirm != true || !mounted) return;

    final bool? secondConfirm = await showDialog<bool>(context: context, barrierDismissible: false, builder: (context) { final controller = TextEditingController(); return StatefulBuilder(builder: (context, setState) { return AlertDialog(title: const Text('Confirmación Final'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Para confirmar, por favor escribe la palabra "borrar" en el campo de abajo.'), const SizedBox(height: 16), TextField(controller: controller, decoration: const InputDecoration(hintText: 'borrar'), autocorrect: false, textAlign: TextAlign.center, onChanged: (value) => setState(() {}))]), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: controller.text.trim().toLowerCase() == 'borrar' ? Colors.red : Colors.grey.shade400, foregroundColor: Colors.white), onPressed: controller.text.trim().toLowerCase() == 'borrar' ? () => Navigator.of(context).pop(true) : null, child: const Text('Borrar Definitivamente'))]); }); });
    if (secondConfirm != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await FirestoreService.deleteTransactionsBySource(widget.accountName);
      await FirestoreService.deleteCalculatedDataBySource(widget.accountName);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Todos los datos de ${widget.accountName} han sido eliminados.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al borrar los datos: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _calculateAveragePrices() async {
    if (!_apiKeysExist) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, conecta tu API de Binance primero.'), backgroundColor: Colors.orange));
       return;
    }
    setState(() => _isProcessing = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iniciando cálculo de precios promedio... Esto puede tardar.')));

    try {
      final currentPortfolio = await PortfolioCalculator.calculate(allTransactions: _allTransactions, marketPrices: widget.marketPrices, sourceAccount: widget.accountName);
      if (currentPortfolio.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay activos en Binance para calcular.')));
        setState(() => _isProcessing = false);
        return;
      }

      final binanceTransactions = _allTransactions.where((tx) => tx.sourceAccount == widget.accountName).toList();
      for (final asset in currentPortfolio) {
        final result = await BinanceCostCalculator.calculateWeightedAveragePrice(
          assetIdToCalculate: asset.coinId,
          allBinanceTransactions: binanceTransactions,
        );
        await FirestoreService.updateCalculatedAssetData(
          sourceAccount: widget.accountName, 
          assetId: asset.coinId, 
          dataToUpdate: result,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Cálculo de precios promedio completado!'), backgroundColor: Colors.green));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en el cálculo: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showEditPriceDialog(PortfolioAsset asset) async {
    final priceController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Precio Prom. de ${asset.ticker}'),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Nuevo Precio Promedio',
            hintText: asset.averageBuyPrice.toStringAsFixed(4),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(priceController.text), child: const Text('Guardar')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final newPrice = double.tryParse(result);
      if (newPrice != null) {
        final newTotalInvested = newPrice * asset.totalAmount;
        await FirestoreService.updateCalculatedAssetData(
          sourceAccount: widget.accountName, 
          assetId: asset.coinId, 
          dataToUpdate: {
            'averageBuyPrice': newPrice,
            'totalInvestedUSD': newTotalInvested,
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalle de ${widget.accountName}')),
      body: StreamBuilder<List<Transaction>>(
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
              return FutureBuilder<List<PortfolioAsset>>(
                future: PortfolioCalculator.calculate(allTransactions: _allTransactions, marketPrices: widget.marketPrices, sourceAccount: widget.accountName),
                builder: (context, portfolioSnapshot) {
                  if (portfolioSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (portfolioSnapshot.hasError) {
                    return Center(child: Text('Error al calcular portafolio: ${portfolioSnapshot.error}'));
                  }
                  final fullPortfolio = portfolioSnapshot.data ?? [];
                  for (var asset in fullPortfolio) {
                    final docId = '${widget.accountName}_${asset.coinId}';
                    if (calculatedData.containsKey(docId)) {
                      asset.averageBuyPrice = (calculatedData[docId]!['averageBuyPrice'] as num?)?.toDouble() ?? 0.0;
                      asset.totalInvestedUSD = (calculatedData[docId]!['totalInvestedUSD'] as num?)?.toDouble() ?? 0.0;
                    }
                  }
                  final spotAssets = <PortfolioAsset>[];
                  final earnAssets = <PortfolioAsset>[];
                  for (var asset in fullPortfolio) {
                    final spotVersion = PortfolioAsset(sourceAccount: asset.sourceAccount, coinId: asset.coinId, name: asset.name, ticker: asset.ticker, balances: {}, averageBuyPrice: asset.averageBuyPrice, totalInvestedUSD: asset.totalInvestedUSD);
                    final earnVersion = PortfolioAsset(sourceAccount: asset.sourceAccount, coinId: asset.coinId, name: asset.name, ticker: asset.ticker, balances: {}, averageBuyPrice: asset.averageBuyPrice, totalInvestedUSD: asset.totalInvestedUSD);
                    asset.balances.forEach((wallet, amount) {
                      if (amount.abs() > 1e-8) {
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
                    onRefresh: () async => setState((){}),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _isProcessing ? const Center(child: CircularProgressIndicator()) : Wrap(
                              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                              children: [
                                ElevatedButton.icon(onPressed: _importTransactions, icon: const Icon(Icons.upload_file), label: const Text('Importar (CSV)')),
                                ElevatedButton.icon(onPressed: _handleApiConnection, icon: Icon(_apiKeysExist ? Icons.link_off : Icons.link), label: Text(_apiKeysExist ? 'Desconectar API' : 'Conectar API'), style: ElevatedButton.styleFrom(backgroundColor: _apiKeysExist ? Colors.orange.shade700 : Theme.of(context).primaryColor, foregroundColor: Colors.white)),
                                ElevatedButton.icon(onPressed: _calculateAveragePrices, icon: const Icon(Icons.price_change_outlined), label: const Text('Calcular Precios'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white)),
                                ElevatedButton.icon(onPressed: _showDeleteConfirmationDialog, icon: const Icon(Icons.delete_forever), label: const Text('Borrar Datos'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white)),
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
            }
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
          return CryptoCoinCard(
            asset: asset, 
            marketCoin: marketCoin,
            onEdit: () => _showEditPriceDialog(asset), // Pasamos la función de editar
          );
        },
        childCount: assets.length,
      ),
    );
  }

  Widget _buildEmptySection() {
    return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No hay activos en esta billetera.', style: TextStyle(color: Colors.grey)))));
  }
}