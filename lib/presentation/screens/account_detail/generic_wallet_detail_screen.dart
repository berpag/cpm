// lib/presentation/screens/account_detail/generic_wallet_detail_screen.dart

import 'dart:async';
import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/price_service.dart';
import 'package:cpm/data/services/solana_api_service.dart';
import 'package:cpm/data/services/bitcoin_api_service.dart';
import 'package:cpm/data/services/evm_api_service.dart';
import 'package:cpm/data/services/xrp_api_service.dart';
import 'package:cpm/data/services/stellar_api_service.dart';
import 'package:cpm/data/services/near_api_service.dart';
import 'package:cpm/data/services/cardano_api_service.dart';
import 'package:cpm/data/services/bittensor_api_service.dart';
import 'package:cpm/presentation/screens/account_detail/manage_wallet_networks_screen.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/data/services/token_encyclopedia_service.dart';
import 'package:cpm/data/services/hedera_api_service.dart';

class RawAsset {
  final String network;
  final String contract;
  final double amount;
  RawAsset({required this.network, required this.contract, required this.amount});
  Map<String, dynamic> toMap() => {'network': network, 'contract': contract, 'amount': amount};
}

class GenericWalletDetailScreen extends StatefulWidget {
  final String walletName;
  const GenericWalletDetailScreen({super.key, required this.walletName});

  @override
  State<GenericWalletDetailScreen> createState() => _GenericWalletDetailScreenState();
}

class _GenericWalletDetailScreenState extends State<GenericWalletDetailScreen> {
  bool _isProcessing = false;
  Map<String, String> _networks = {};
  double _totalWalletValue = 0.0;
  String _syncStatus = '';

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    final networks = await FirestoreService.getWalletNetworks(widget.walletName);
    if (mounted) setState(() => _networks = networks);
  }
  
  Future<void> _startFullSyncProcess() async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; _syncStatus = 'Capturando balances...'; });
    try {
      final rawAssets = await _captureRawBalances();
      await FirestoreService.saveRawBalances(walletName: widget.walletName, rawAssets: rawAssets.map((e) => e.toMap()).toList());
      await _processAndSyncData(rawAssets);
    } catch(e) {
      print('[SYNC-FATAL] Error en el proceso de sincronización: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ocurrió un error inesperado.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isProcessing = false; _syncStatus = ''; });
    }
  }

  Future<List<RawAsset>> _captureRawBalances() async {
    print('[SYNC-CAPTURE] Iniciando captura...');
    final List<RawAsset> allRawAssets = [];
    Future<void> fetch(String key, Future<Map<String, double>> Function(String) fetcher) async {
      if (!_networks.containsKey(key) || _networks[key]!.isEmpty) return;
      print('[SYNC-CAPTURE] Consultando ${key.toUpperCase()}...');
      try {
        final balances = await fetcher(_networks[key]!);
        balances.forEach((contract, amount) {
          allRawAssets.add(RawAsset(network: key, contract: contract, amount: amount));
        });
      } catch (e) { print('[SYNC-CAPTURE] Error en fetcher para $key: $e'); }
    }
    
    await fetch('solana', SolanaApiService.getTokenBalances);
    if (_networks.containsKey('evm') && _networks['evm']!.isNotEmpty) {
      final evmNetworks = ['ethereum', 'bsc', 'arbitrum', 'polygon', 'base'];
      for (var network in evmNetworks) {
        print('[SYNC-CAPTURE] Consultando EVM/${network.toUpperCase()}...');
        try {
          final balances = await EvmApiService.getAllBalances(network: network, address: _networks['evm']!);
          balances.forEach((token) {
            allRawAssets.add(RawAsset(network: network, contract: token.contractAddress, amount: token.amount));
          });
        } catch (e) { print('[SYNC-CAPTURE] Error en fetcher para EVM/$network: $e'); }
      }
    }
    await fetch('bitcoin', BitcoinApiService.getBitcoinBalance);
    await fetch('xrp', XrpApiService.getXrpBalance);
    await fetch('stellar', StellarApiService.getXlmBalance);
    await fetch('near', NearApiService.getNearBalance);
    await fetch('cardano', CardanoApiService.getAdaBalance);
    await fetch('bittensor', BittensorApiService.getTaoBalance);
    print('[SYNC-CAPTURE] Captura finalizada: ${allRawAssets.length} activos crudos.');
    return allRawAssets;
  }

  Future<void> _processAndSyncData(List<RawAsset> rawAssets) async {
    if (!mounted) return;
    setState(() => _syncStatus = 'Procesando ${rawAssets.length} activos...');
    final existingTxs = (await FirestoreService.getTransactionsStream().first).where((tx) => tx.sourceAccount == widget.walletName).toList();
    List<app_models.Transaction> toUpdate = [];
    bool rateLimitHit = false;

    for (int i = 0; i < rawAssets.length; i++) {
      if (rateLimitHit) break;
      final rawAsset = rawAssets[i];
      if (!mounted) break;
      setState(() => _syncStatus = 'Procesando ${i + 1}/${rawAssets.length}: ${_formatContract(rawAsset.contract)}');

      TokenInfo? tokenInfo = await _findOrLearnToken(rawAsset);
      if (tokenInfo?.id == 'RATE_LIMIT_EXCEEDED') {
        rateLimitHit = true;
      }
      
      final existingTx = existingTxs.firstWhere((tx) => (tx.rawContract == rawAsset.contract && tx.rawNetwork == rawAsset.network), orElse: () => _createPlaceholderTransaction(rawAsset));
      final newTx = _createTransactionFromRaw(rawAsset, tokenInfo);
      
      if (existingTx.id == null || (existingTx.cryptoAmount - newTx.cryptoAmount).abs() > 1e-9 || existingTx.cryptoCoinId != newTx.cryptoCoinId) {
        toUpdate.add(newTx.copyWith(id: existingTx.id));
      }
    }

    if (toUpdate.isNotEmpty) await FirestoreService.addOrUpdateTransactionsInBatch(toUpdate);
    
    if (!rateLimitHit) {
      final toDelete = existingTxs.where((tx) => !rawAssets.any((a) => a.contract == tx.rawContract && a.network == tx.rawNetwork)).toList();
      if (toDelete.isNotEmpty) {
        await FirestoreService.deleteTransactionsInBatch(toDelete);
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(rateLimitHit ? 'Sincronización parcial. Intenta de nuevo más tarde.' : 'Sincronización completada.'),
        backgroundColor: rateLimitHit ? Colors.orange : Colors.green,
      ));
    }
  }
  
  app_models.Transaction _createPlaceholderTransaction(RawAsset rawAsset) {
    return app_models.Transaction(
      sourceAccount: widget.walletName, type: 'Balance Sync', date: DateTime.now(),
      wallet: rawAsset.network.toUpperCase(),
      cryptoCoinId: 'unknown_${rawAsset.contract}',
      cryptoAmount: rawAsset.amount,
      rawNetwork: rawAsset.network,
      rawContract: rawAsset.contract,
    );
  }
  
  app_models.Transaction _createTransactionFromRaw(RawAsset rawAsset, TokenInfo? tokenInfo) {
    return app_models.Transaction(
      sourceAccount: widget.walletName, type: 'Balance Sync', date: DateTime.now(),
      wallet: rawAsset.network.toUpperCase(),
      cryptoCoinId: tokenInfo?.id ?? 'unknown_${rawAsset.contract}',
      cryptoAmount: rawAsset.amount,
      rawNetwork: rawAsset.network,
      rawContract: rawAsset.contract,
    );
  }

  Future<TokenInfo?> _findOrLearnToken(RawAsset rawAsset) async {
    final coinId = _getKnownCoinId(rawAsset.contract);
    if(coinId != null) {
      var tokenInfo = await TokenEncyclopediaService.getTokenInfoById(coinId);
      if (tokenInfo == null) tokenInfo = await _learnAboutToken(coinId: coinId);
      return tokenInfo;
    } else {
      var tokenInfo = await TokenEncyclopediaService.findTokenByContractAddress(rawAsset.network, rawAsset.contract);
      if (tokenInfo == null) tokenInfo = await _learnAboutToken(platform: rawAsset.network, contract: rawAsset.contract);
      return tokenInfo;
    }
  }

  Future<TokenInfo?> _learnAboutToken({String? coinId, String? platform, String? contract}) async {
    await Future.delayed(const Duration(milliseconds: 2500));
    try {
      TokenInfo? learnedToken;
      if (coinId != null) {
        print('[Resolver] Aprendiendo por ID: $coinId...');
        final coins = await ApiService.getPricesFromCoinGecko([coinId]);
        if (coins.isNotEmpty) {
          final coin = coins.first;
          learnedToken = TokenInfo(id: coin.id, name: coin.name, symbol: coin.ticker, logoUrl: coin.logoUrl, platforms: {});
        }
      } else if (platform != null && contract != null) {
        print('[Resolver] Aprendiendo por Contrato: $contract en $platform...');
        learnedToken = await ApiService.getTokenInfoByContractAddress(platform, contract);
      }
      if (learnedToken?.id == 'RATE_LIMIT_EXCEEDED') return learnedToken;
      if (learnedToken != null) await TokenEncyclopediaService.saveTokenInfo(learnedToken);
      return learnedToken;
    } catch (e) {
      print('[Resolver] Error de API. Asumiendo Rate Limit: $e');
      return TokenInfo(id: 'RATE_LIMIT_EXCEEDED', name: '', symbol: '');
    }
  }

  String? _getKnownCoinId(String contractOrSymbol) {
    const map = {'BTC': 'bitcoin', 'XRP': 'ripple', 'XLM': 'stellar', 'NEAR': 'near-protocol', 'ADA': 'cardano', 'TAO': 'bittensor', 'HBAR': 'hedera-hashgraph'};
    if (contractOrSymbol == 'SOL') return 'solana';
    return map[contractOrSymbol];
  }

  String _formatContract(String? contract) {
    if (contract == null || contract.length < 8) return contract ?? '...';
    return '${contract.substring(0, 4)}...${contract.substring(contract.length - 4)}';
  }

  Future<Map<String, TokenInfo?>> _enrichPortfolioWithEncyclopediaData(List<app_models.PortfolioAsset> assets) async {
    final map = <String, TokenInfo?>{};
    for (final asset in assets) {
      if (asset.coinId.startsWith('unknown_')) {
        map[asset.coinId] = await TokenEncyclopediaService.findTokenByContractAddress(asset.rawNetwork!, asset.rawContract!);
      } else {
        map[asset.coinId] = await TokenEncyclopediaService.getTokenInfoById(asset.coinId);
      }
    }
    return map;
  }

  Future<void> _showEditPriceDialog(app_models.PortfolioAsset asset) async {
    final priceController = TextEditingController();
    if (asset.averageBuyPrice > 0) priceController.text = asset.averageBuyPrice.toStringAsFixed(4);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Precio Prom. de ${asset.ticker}'),
        content: TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Nuevo Precio Promedio', hintText: asset.averageBuyPrice.toStringAsFixed(4)), autofocus: true),
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
          sourceAccount: widget.walletName,
          assetId: asset.coinId,
          dataToUpdate: {'averageBuyPrice': newPrice, 'totalInvestedUSD': newTotalInvested},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Precio promedio de ${asset.ticker} actualizado.'), backgroundColor: Colors.green));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Detalle de ${widget.walletName}'),
            if (_totalWalletValue > 0.01)
              Text(NumberFormat.currency(locale: 'en_US', symbol: '\$').format(_totalWalletValue), style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: StreamBuilder<List<app_models.Transaction>>(
        stream: FirestoreService.getTransactionsStream(),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting && !transactionSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final walletTransactions = (transactionSnapshot.data ?? []).where((tx) => tx.sourceAccount == widget.walletName).toList();
          
          if (walletTransactions.isEmpty && !_isProcessing) {
            return CustomScrollView(slivers: [_buildHeader(), const SliverFillRemaining(child: Center(child: Text('No hay activos. Pulsa Sincronizar.')))]);
          }

          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: FirestoreService.getCalculatedPortfolioStream(),
            builder: (context, calculatedDataSnapshot) {
              if (calculatedDataSnapshot.connectionState == ConnectionState.waiting && !calculatedDataSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final calculatedData = calculatedDataSnapshot.data ?? {};
              return FutureBuilder<List<app_models.PortfolioAsset>>(
                future: PortfolioCalculator.calculate(allTransactions: walletTransactions, marketPrices: const []),
                builder: (context, portfolioSnapshot) {
                  if (portfolioSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final portfolioAssets = portfolioSnapshot.data ?? [];
                  return FutureBuilder<Map<String, TokenInfo?>>(
                    future: _enrichPortfolioWithEncyclopediaData(portfolioAssets),
                    builder: (context, encyclopediaSnapshot) {
                      if (encyclopediaSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final tokenInfoMap = encyclopediaSnapshot.data ?? {};
                      double currentTotalValue = 0.0;
                      Map<String, double> assetValues = {};
                      for (var asset in portfolioAssets) {
                        final docId = '${widget.walletName}_${asset.coinId}';
                        final price = (calculatedData[docId]?['currentPrice'] as num?)?.toDouble() ?? 0.0;
                        final value = asset.totalAmount * price;
                        assetValues[asset.coinId] = value;
                        currentTotalValue += value;
                      }
                      portfolioAssets.sort((a, b) => (assetValues[b.coinId] ?? 0.0).compareTo(assetValues[a.coinId] ?? 0.0));
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _totalWalletValue != currentTotalValue) setState(() => _totalWalletValue = currentTotalValue);
                      });
                      return CustomScrollView(
                        slivers: [
                          _buildHeader(),
                          if (_isProcessing)
                            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                              const SizedBox(width: 16),
                              Expanded(child: Text(_syncStatus, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
                            ]))),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final asset = portfolioAssets[index];
                                final tokenInfo = tokenInfoMap[asset.coinId];
                                final price = asset.totalAmount > 0 ? (assetValues[asset.coinId] ?? 0.0) / asset.totalAmount : 0.0;
                                final marketCoin = app_models.CryptoCoin(
                                  id: asset.coinId,
                                  name: tokenInfo?.name ?? (asset.rawNetwork?.toUpperCase() ?? 'Desconocido'),
                                  ticker: tokenInfo?.symbol ?? _formatContract(asset.rawContract),
                                  price: price,
                                  logoUrl: tokenInfo?.logoUrl,
                                );
                                final displayAsset = asset.copyWith(ticker: marketCoin.ticker, name: marketCoin.name);
                                return CryptoCoinCard(asset: displayAsset, marketCoin: marketCoin, onEdit: () => _showEditPriceDialog(asset));
                              },
                              childCount: portfolioAssets.length,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
    
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Redes Conectadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _networks.isEmpty
              ? const Text('Ninguna red configurada todavía.', style: TextStyle(color: Colors.grey))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: _networks.keys.map((key) => Text('• ${key.toUpperCase()}', style: const TextStyle(fontSize: 16))).toList()),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.settings), label: const Text('Configurar Redes'), onPressed: _isProcessing ? null : () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => ManageWalletNetworksScreen(walletName: widget.walletName)));
                  _loadNetworks();
                })),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.sync), label: const Text('Sincronizar'), onPressed: _isProcessing ? null : _startFullSyncProcess, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}