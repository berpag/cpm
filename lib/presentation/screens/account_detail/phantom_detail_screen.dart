// lib/presentation/screens/account_detail/phantom_detail_screen.dart

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/price_service.dart';
import 'package:cpm/data/services/solana_api_service.dart';
import 'package:cpm/data/services/bitcoin_api_service.dart'; // <-- IMPORT AÑADIDO
import 'package:cpm/presentation/screens/account_detail/manage_wallet_networks_screen.dart';
import 'package:cpm/data/services/secure_storage_service.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:flutter/material.dart';

class PhantomDetailScreen extends StatefulWidget {
  const PhantomDetailScreen({super.key});

  @override
  State<PhantomDetailScreen> createState() => _PhantomDetailScreenState();
}

class _PhantomDetailScreenState extends State<PhantomDetailScreen> {
  bool _isProcessing = false;
  Map<String, String> _networks = {};
  List<PortfolioAsset> _portfolioAssets = [];
  List<CryptoCoin> _marketPrices = [];

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    final networks = await SecureStorageService.getWalletNetworks('Phantom');
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
    
    setState(() {
      _isProcessing = true;
      _portfolioAssets = [];
      _marketPrices = [];
    });

    List<PortfolioAsset> allFoundAssets = [];

    try {
      // --- SINCRONIZAR SOLANA (si está configurada) ---
      if (_networks.containsKey('solana') && _networks['solana']!.isNotEmpty) {
        print('--- Iniciando Sincronización de Solana ---');
        final solanaAssets = await _fetchSolanaBalances(_networks['solana']!);
        allFoundAssets.addAll(solanaAssets);
      }

      // --- SINCRONIZAR BITCOIN (si está configurada) ---
      if (_networks.containsKey('bitcoin') && _networks['bitcoin']!.isNotEmpty) {
        print('--- Iniciando Sincronización de Bitcoin ---');
        final bitcoinAssets = await _fetchBitcoinBalances(_networks['bitcoin']!);
        allFoundAssets.addAll(bitcoinAssets);
      }
      
      // --- SINCRONIZAR EVM (si está configurada) ---
      if (_networks.containsKey('evm') && _networks['evm']!.isNotEmpty) {
        print('--- Iniciando Sincronización de EVM (Ethereum, etc.) ---');
        // TODO: Llamar a _fetchEvmBalances(_networks['evm']!) cuando lo implementemos
      }

      // --- Obtener precios para todos los activos encontrados en todas las redes ---
      final allCoinIds = allFoundAssets.map((asset) => asset.coinId).toSet().toList();
      if (allCoinIds.isNotEmpty) {
        final prices = await PriceService.getMarketPricesForIds(allCoinIds);
         if (mounted) {
          _marketPrices = prices;
        }
      }
     
      if (mounted) {
        setState(() {
          _portfolioAssets = allFoundAssets;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Sincronización completada!'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<List<PortfolioAsset>> _fetchSolanaBalances(String address) async {
    final solanaTokenList = await ApiService.getSolanaTokenList();
    final tokenMap = { for (var token in solanaTokenList) (token['platforms']['solana'] as String): token };
    tokenMap['So11111111111111111111111111111111111111112'] = {'id': 'solana', 'symbol': 'SOL', 'name': 'Solana'};

    final rawBalances = await SolanaApiService.getTokenBalances(address);
    final List<PortfolioAsset> assets = [];

    for (var entry in rawBalances.entries) {
      final mintOrSymbol = entry.key;
      final amount = entry.value;
      
      final lookupKey = mintOrSymbol == 'SOL' ? 'So11111111111111111111111111111111111111112' : mintOrSymbol;
      final tokenInfo = tokenMap[lookupKey];
      
      if (tokenInfo != null) {
        assets.add(
          PortfolioAsset(
            sourceAccount: 'Phantom',
            coinId: tokenInfo['id'] as String,
            name: tokenInfo['name'] as String,
            ticker: (tokenInfo['symbol'] as String).toUpperCase(),
            balances: {'Solana Wallet': amount},
            totalInvestedUSD: 0.0,
            averageBuyPrice: 0.0,
          )
        );
      }
    }
    return assets;
  }

  // --- ¡NUEVA FUNCIÓN AUXILIAR PARA BITCOIN! ---
  Future<List<PortfolioAsset>> _fetchBitcoinBalances(String address) async {
    final btcBalance = await BitcoinApiService.getBitcoinBalance(address);
    if (btcBalance.containsKey('BTC')) {
      return [
        PortfolioAsset(
          sourceAccount: 'Phantom',
          coinId: 'bitcoin',
          name: 'Bitcoin',
          ticker: 'BTC',
          balances: {'Bitcoin Wallet': btcBalance['BTC']!},
          totalInvestedUSD: 0.0,
          averageBuyPrice: 0.0,
        )
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Phantom'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
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
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.settings),
                          label: const Text('Configurar Redes'),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ManageWalletNetworksScreen(walletName: 'Phantom')),
                            );
                            _loadNetworks();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.sync),
                          label: const Text('Sincronizar'),
                          onPressed: _isProcessing ? null : _syncBalances,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (_isProcessing)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_portfolioAssets.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    _networks.isEmpty 
                      ? 'Configura una red para empezar.'
                      : 'Aún no has sincronizado o no se encontraron balances.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final asset = _portfolioAssets[index];
                  final marketCoin = _marketPrices.firstWhere(
                    (c) => c.id == asset.coinId,
                    orElse: () => CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0),
                  );
                  return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
                },
                childCount: _portfolioAssets.length,
              ),
            ),
        ],
      ),
    );
  }
}