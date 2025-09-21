// lib/presentation/screens/account_detail/generic_wallet_detail_screen.dart

import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/price_service.dart';
import 'package:cpm/data/services/solana_api_service.dart';
import 'package:cpm/data/services/bitcoin_api_service.dart';
import 'package:cpm/data/services/evm_api_service.dart';
import 'package:cpm/data/services/xrp_api_service.dart';
import 'package:cpm/data/services/stellar_api_service.dart';
import 'package:cpm/data/services/hedera_api_service.dart';
import 'package:cpm/data/services/near_api_service.dart';
import 'package:cpm/data/services/cardano_api_service.dart';
import 'package:cpm/data/services/bittensor_api_service.dart';
import 'package:cpm/presentation/screens/account_detail/manage_wallet_networks_screen.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';

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

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    final networks = await FirestoreService.getWalletNetworks(widget.walletName);
    if (mounted) {
      setState(() {
        _networks = networks;
      });
    }
  }

  Future<void> _syncBalances() async {
    if (_networks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay redes configuradas. Añade una para sincronizar.'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _isProcessing = true);
    print('[DEBUG-SYNC-1] Iniciando _syncBalances para ${widget.walletName}');

    try {
      final foundAssets = await _fetchAllNetworkBalances();
      print('[DEBUG-SYNC-2] _fetchAllNetworkBalances devolvió ${foundAssets.length} activos consolidados.');

      final List<app_models.Transaction> newTransactions = [];
      final syncTime = DateTime.now();

      for (final asset in foundAssets) {
        if (asset.totalAmount.abs() > 0.00000001) {
          newTransactions.add(app_models.Transaction(
            sourceAccount: widget.walletName,
            type: 'Balance Sync',
            date: syncTime,
            wallet: asset.balances.keys.first,
            cryptoCoinId: asset.coinId,
            cryptoAmount: asset.totalAmount,
          ));
        }
      }
      print('[DEBUG-SYNC-3] Se crearon ${newTransactions.length} nuevas transacciones para guardar.');
      
      await FirestoreService.deleteTransactionsBySource(widget.walletName);
      print('[DEBUG-SYNC-4] Transacciones antiguas de ${widget.walletName} eliminadas.');

      if (newTransactions.isNotEmpty) {
        await FirestoreService.addTransactionsInBatch(newTransactions);
        print('[DEBUG-SYNC-5] ${newTransactions.length} nuevas transacciones guardadas en Firestore.');
      }
      
      final allCoinIds = newTransactions.map((tx) => tx.cryptoCoinId).toSet().toList();
      if (allCoinIds.isNotEmpty) {
        print('[DEBUG-SYNC-6] Obteniendo precios para: $allCoinIds');
        final prices = await PriceService.getMarketPricesForIds(allCoinIds);
        print('[DEBUG-SYNC-7] Se obtuvieron ${prices.length} precios.');
        for (final coinPrice in prices) {
          await FirestoreService.updateCalculatedAssetData(
            sourceAccount: widget.walletName,
            assetId: coinPrice.id,
            dataToUpdate: {'currentPrice': coinPrice.price},
          );
        }
        print('[DEBUG-SYNC-8] Precios guardados en la caché de Firestore.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Sincronización con Firestore completada!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('[DEBUG-SYNC-ERROR] Error durante la sincronización: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    }
  }

  Future<List<app_models.PortfolioAsset>> _fetchAllNetworkBalances() async {
    final networkFutures = <Future<List<app_models.PortfolioAsset>>>[];
    
    if (_networks.containsKey('solana') && _networks['solana']!.isNotEmpty) {
      networkFutures.add(_fetchSolanaBalances(_networks['solana']!));
    }
    if (_networks.containsKey('bitcoin') && _networks['bitcoin']!.isNotEmpty) {
      networkFutures.add(_fetchBitcoinBalances(_networks['bitcoin']!));
    }
    if (_networks.containsKey('evm') && _networks['evm']!.isNotEmpty) {
      networkFutures.add(_fetchEvmBalances(_networks['evm']!));
    }
    if (_networks.containsKey('xrp') && _networks['xrp']!.isNotEmpty) {
      networkFutures.add(_fetchXrpBalances(_networks['xrp']!));
    }
    if (_networks.containsKey('stellar') && _networks['stellar']!.isNotEmpty) {
      networkFutures.add(_fetchStellarBalances(_networks['stellar']!));
    }
    if (_networks.containsKey('hedera') && _networks['hedera']!.isNotEmpty) {
      networkFutures.add(_fetchHederaBalances(_networks['hedera']!));
    }
    if (_networks.containsKey('near') && _networks['near']!.isNotEmpty) {
      networkFutures.add(_fetchNearBalances(_networks['near']!));
    }
    if (_networks.containsKey('cardano') && _networks['cardano']!.isNotEmpty) {
      networkFutures.add(_fetchCardanoBalances(_networks['cardano']!));
    }
    if (_networks.containsKey('bittensor') && _networks['bittensor']!.isNotEmpty) {
      networkFutures.add(_fetchBittensorBalances(_networks['bittensor']!));
    }

    final results = await Future.wait(networkFutures);
    
    List<app_models.PortfolioAsset> allFoundAssets = [];
    for (var assetList in results) {
      allFoundAssets.addAll(assetList);
    }

    final consolidatedAssets = <String, app_models.PortfolioAsset>{};
    for (var asset in allFoundAssets) {
      if (consolidatedAssets.containsKey(asset.coinId)) {
        final existingAsset = consolidatedAssets[asset.coinId]!;
        asset.balances.forEach((wallet, amount) {
          existingAsset.balances.update(wallet, (value) => value + amount, ifAbsent: () => amount);
        });
      } else {
        consolidatedAssets[asset.coinId] = asset;
      }
    }
    return consolidatedAssets.values.toList();
  }

  Future<List<app_models.PortfolioAsset>> _fetchSolanaBalances(String address) async {
    final solanaTokenList = await ApiService.getSolanaTokenList();
    final tokenMap = { for (var token in solanaTokenList) (token['platforms']['solana'] as String): token };
    tokenMap['So11111111111111111111111111111111111111112'] = {'id': 'solana', 'symbol': 'SOL', 'name': 'Solana'};
    final rawBalances = await SolanaApiService.getTokenBalances(address);
    final List<app_models.PortfolioAsset> assets = [];
    for (var entry in rawBalances.entries) {
      final lookupKey = entry.key == 'SOL' ? 'So11111111111111111111111111111111111111112' : entry.key;
      final tokenInfo = tokenMap[lookupKey];
      if (tokenInfo != null) {
        assets.add(app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: tokenInfo['id'] as String, name: tokenInfo['name'] as String, ticker: (tokenInfo['symbol'] as String).toUpperCase(), balances: {'Solana': entry.value}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0));
      }
    }
    return assets;
  }

  Future<List<app_models.PortfolioAsset>> _fetchBitcoinBalances(String address) async {
    final btcBalance = await BitcoinApiService.getBitcoinBalance(address);
    if (btcBalance.containsKey('BTC')) {
      return [app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: 'bitcoin', name: 'Bitcoin', ticker: 'BTC', balances: {'Bitcoin': btcBalance['BTC']!}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0)];
    }
    return [];
  }

  Future<List<app_models.PortfolioAsset>> _fetchEvmBalances(String address) async {
    final List<app_models.PortfolioAsset> assets = [];
    final evmNetworksToSync = ['bsc', 'arbitrum', 'polygon', 'ethereum', 'base', 'mode'];
    final coinIdMap = {'ETH_arbitrum': 'ethereum', 'ONDO_ethereum': 'ondo-finance', 'LINK_bsc': 'chainlink', 'DOGE_bsc': 'dogecoin', 'PENDLE_arbitrum': 'pendle'};
    final networkFutures = evmNetworksToSync.map((network) => EvmApiService.getAllBalances(network: network, address: address)).toList();
    final results = await Future.wait(networkFutures);
    for (int i = 0; i < results.length; i++) {
      final network = evmNetworksToSync[i];
      for (final balance in results[i]) {
        if (balance.amount > 0.00001) {
          final specificIdKey = '${balance.symbol}_$network';
          final coinId = coinIdMap[specificIdKey] ?? balance.symbol.toLowerCase();
          assets.add(app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: coinId, name: balance.name, ticker: balance.symbol, balances: {'${network.toUpperCase()}': balance.amount}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0));
        }
      }
    }
    return assets;
  }
  
  Future<List<app_models.PortfolioAsset>> _fetchXrpBalances(String address) async {
    final xrpBalance = await XrpApiService.getXrpBalance(address);
    if (xrpBalance.containsKey('XRP')) {
      return [app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: 'ripple', name: 'XRP', ticker: 'XRP', balances: {'XRP Ledger': xrpBalance['XRP']!}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0)];
    }
    return [];
  }

  Future<List<app_models.PortfolioAsset>> _fetchStellarBalances(String address) async {
    final xlmBalance = await StellarApiService.getXlmBalance(address);
    if (xlmBalance.containsKey('XLM')) {
      return [app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: 'stellar', name: 'Stellar', ticker: 'XLM', balances: {'Stellar': xlmBalance['XLM']!}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0)];
    }
    return [];
  }

  Future<List<app_models.PortfolioAsset>> _fetchHederaBalances(String address) async {
    final hbarBalance = await HederaApiService.getHbarBalance(address);
    if (hbarBalance.containsKey('HBAR')) {
      return [app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: 'hedera-hashgraph', name: 'Hedera', ticker: 'HBAR', balances: {'Hedera': hbarBalance['HBAR']!}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0)];
    }
    return [];
  }

  Future<List<app_models.PortfolioAsset>> _fetchNearBalances(String address) async {
    final nearBalance = await NearApiService.getNearBalance(address);
    if (nearBalance.containsKey('NEAR')) {
      return [app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: 'near', name: 'NEAR Protocol', ticker: 'NEAR', balances: {'NEAR': nearBalance['NEAR']!}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0)];
    }
    return [];
  }
  
  Future<List<app_models.PortfolioAsset>> _fetchCardanoBalances(String address) async {
    final adaBalance = await CardanoApiService.getAdaBalance(address);
    if (adaBalance.containsKey('ADA')) {
      return [app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: 'cardano', name: 'Cardano', ticker: 'ADA', balances: {'Cardano': adaBalance['ADA']!}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0)];
    }
    return [];
  }

  Future<List<app_models.PortfolioAsset>> _fetchBittensorBalances(String address) async {
    final taoBalance = await BittensorApiService.getTaoBalance(address);
    if (taoBalance.containsKey('TAO')) {
      return [app_models.PortfolioAsset(sourceAccount: widget.walletName, coinId: 'bittensor', name: 'Bittensor', ticker: 'TAO', balances: {'Bittensor': taoBalance['TAO']!}, totalInvestedUSD: 0.0, averageBuyPrice: 0.0)];
    }
    return [];
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
              Text(
                NumberFormat.currency(locale: 'en_US', symbol: '\$').format(_totalWalletValue),
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  // --- CÓDIGO ELIMINADO ---
                  // Ya no especificamos el color aquí, lo hereda del tema global.
                ),
              ),
          ],
        ),
      ),
      body: StreamBuilder<List<app_models.Transaction>>(
        stream: FirestoreService.getTransactionsStream(),
        builder: (context, transactionSnapshot) {
          if (!transactionSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final allTransactions = transactionSnapshot.data!;

          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: FirestoreService.getCalculatedPortfolioStream(),
            builder: (context, calculatedDataSnapshot) {
              if (!calculatedDataSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              final calculatedData = calculatedDataSnapshot.data!;

              return FutureBuilder<List<app_models.PortfolioAsset>>(
                future: PortfolioCalculator.calculate(
                  allTransactions: allTransactions,
                  marketPrices: [],
                  sourceAccount: widget.walletName
                ),
                builder: (context, portfolioSnapshot) {
                  if (!portfolioSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final portfolioAssets = portfolioSnapshot.data!;
                  double currentTotalValue = 0.0;

                  // Creamos una lista temporal para poder ordenarla
                  List<app_models.PortfolioAsset> sortedAssets = List.from(portfolioAssets);
                  Map<String, double> assetValues = {};

                  for (var asset in sortedAssets) {
                    final docId = '${widget.walletName}_${asset.coinId}';
                    final price = (calculatedData[docId]?['currentPrice'] as num?)?.toDouble() ?? 0.0;
                    final value = asset.totalAmount * price;
                    assetValues[asset.coinId] = value;
                    currentTotalValue += value;
                  }

                  // Ordenamos la lista basándonos en el valor calculado
                  sortedAssets.sort((a, b) {
                    final valueA = assetValues[a.coinId] ?? 0.0;
                    final valueB = assetValues[b.coinId] ?? 0.0;
                    return valueB.compareTo(valueA);
                  });
                  
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _totalWalletValue != currentTotalValue) {
                       setState(() { _totalWalletValue = currentTotalValue; });
                    }
                  });

                  return CustomScrollView(
                    slivers: [
                      _buildHeader(),
                      if (_isProcessing)
                        const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                      else if (sortedAssets.isEmpty)
                        const SliverFillRemaining(child: Center(child: Text('No hay activos en esta wallet.')))
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final asset = sortedAssets[index];
                              final docId = '${widget.walletName}_${asset.coinId}';
                              final price = (calculatedData[docId]?['currentPrice'] as num?)?.toDouble() ?? 0.0;
                              final marketCoin = app_models.CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: price);

                              return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
                            },
                            childCount: sortedAssets.length,
                          ),
                        ),
                    ],
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _networks.keys.map((key) => Text('• ${key.toUpperCase()}', style: const TextStyle(fontSize: 16))).toList(),
                ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.settings), label: const Text('Configurar Redes'), onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => ManageWalletNetworksScreen(walletName: widget.walletName)));
                  _loadNetworks();
                })),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.sync), label: const Text('Sincronizar'), onPressed: _isProcessing ? null : _syncBalances, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}