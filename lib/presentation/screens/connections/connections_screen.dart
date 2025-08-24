// lib/presentation/screens/connections/connections_screen.dart

import 'package:flutter/material.dart';
import 'package:cpm/presentation/screens/connections/widgets/api_key_dialog.dart';
import 'package:cpm/data/services/binance_api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/utils/transaction_converter.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});
  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  bool _isLoading = false;
  String _loadingMessage = 'Cargando...';
  List<ApiConnection> _activeConnections = [];
  final List<String> _supportedExchanges = ['Binance', 'CoinEx', 'Bybit', 'BingX', 'MEXC', 'Bitget'];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    setState(() { _isLoading = true; _loadingMessage = 'Cargando conexiones...'; });
    try {
      final connections = await FirestoreService.getConnections();
      if (mounted) setState(() => _activeConnections = connections);
    } catch (e) {
      print("Error cargando conexiones: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showApiKeyDialog(String exchangeName) async {
    final result = await showDialog<Map<String, String>>(context: context, barrierDismissible: false, builder: (context) => ApiKeyDialog(exchangeName: exchangeName));
    if (result != null) {
      final apiKey = result['apiKey']!;
      final secretKey = result['secretKey']!;
      setState(() { _isLoading = true; _loadingMessage = 'Verificando claves...'; });
      try {
        await BinanceApiService.getAccountInfo(apiKey: apiKey, secretKey: secretKey);
        await FirestoreService.saveApiKey(exchangeName: exchangeName, apiKey: apiKey, secretKey: secretKey);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡$exchangeName conectado con éxito!'), backgroundColor: Colors.green));
          _loadConnections(); 
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al conectar: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _syncAllTrades(ApiConnection connection) async {
    setState(() { _isLoading = true; _loadingMessage = 'Iniciando sincronización...'; });
    try {
      final secretKey = await FirestoreService.getSecretKeyFor(connection.exchangeName);
      if (secretKey == null) throw Exception('No se pudo encontrar la Secret Key.');
      final lastSynced = await FirestoreService.getLastSynced(connection.exchangeName);
      final startTime = lastSynced?.millisecondsSinceEpoch;

      setState(() => _loadingMessage = 'Analizando activos y pares...');
      
      final results = await Future.wait([
        BinanceApiService.getAccountInfo(apiKey: connection.apiKey, secretKey: secretKey),
        BinanceApiService.getAllSymbols(),
      ]);
      final spotBalances = results[0] as List<BinanceBalance>;
      final allExchangeSymbols = (results[1] as List<String>).toSet();
      
      final userAssets = spotBalances.map((b) => b.asset).toSet();
      if (userAssets.isEmpty) throw Exception('No se encontraron activos en la billetera Spot para sincronizar.');
      print("[SYNC] Activos del usuario en Spot: $userAssets");

      final symbolsToSync = allExchangeSymbols.where((symbol) {
        return userAssets.any((asset) => symbol.contains(asset));
      }).toList();
      
      print("[SYNC] ${symbolsToSync.length} pares relevantes encontrados para verificar.");
      if (symbolsToSync.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontraron pares de trading para sincronizar.'), backgroundColor: Colors.orange));
        setState(() => _isLoading = false);
        return;
      }
      
      setState(() => _loadingMessage = 'Consultando historial existente...');
      final existingTransactions = await FirestoreService.getTransactions();
      final existingTradeIds = existingTransactions.map((tx) => tx.exchangeTradeId).toSet();
      final marketPrices = await ApiService.getCoins();
      int totalNewTransactions = 0;

      for (var i = 0; i < symbolsToSync.length; i++) {
        final symbol = symbolsToSync[i];
        setState(() => _loadingMessage = 'Verificando ${i + 1}/${symbolsToSync.length}: $symbol...');
        
        final trades = await BinanceApiService.getTradeHistory(
          apiKey: connection.apiKey,
          secretKey: secretKey,
          symbol: symbol,
          startTime: startTime,
        );
        if (trades.isNotEmpty) {
           print("Se encontraron ${trades.length} trades para $symbol. Procesando...");
          for (var trade in trades) {
            final newTransaction = await TransactionConverter.fromBinanceTrade(trade, marketPrices);
            if (newTransaction != null && !existingTradeIds.contains(newTransaction.exchangeTradeId)) {
              await FirestoreService.addTransaction(newTransaction);
              totalNewTransactions++;
              existingTradeIds.add(newTransaction.exchangeTradeId!);
            }
          }
        }
      }

      await FirestoreService.updateLastSynced(connection.exchangeName);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sincronización completa. Se añadieron $totalNewTransactions transacciones nuevas.'), backgroundColor: Colors.green));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error durante la sincronización: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
    @override
  Widget build(BuildContext context) {
    final connectedExchangeNames = _activeConnections.map((c) => c.exchangeName.toLowerCase()).toList();
    final unconnectedExchanges = _supportedExchanges.where((name) => !connectedExchangeNames.contains(name.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Cuentas'),
        backgroundColor: const Color(0xFF1a237e),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                'Exchanges Centralizados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Conecta tus cuentas usando claves API de "solo lectura" para sincronizar tus balances e historial de trades.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              
              ..._activeConnections.map((connection) => _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/${connection.exchangeName.toLowerCase()}_logo.png',
                name: connection.exchangeName,
                isConnected: true,
                onTap: () {},
                trailing: TextButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar'),
                  onPressed: () => _syncAllTrades(connection), 
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              )),

              ...unconnectedExchanges.map((name) => _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/${name.toLowerCase()}_logo.png',
                name: name,
                isConnected: false,
                onTap: () => _showApiKeyDialog(name),
              )),

              const Divider(height: 48, thickness: 1),

              Text(
                'Wallets Descentralizadas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Añade tus direcciones públicas para rastrear tus activos directamente en la blockchain.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              
              _buildConnectionCard(context: context, logoAsset: 'assets/logos/phantom_logo.png', name: 'Phantom (Solana)', isConnected: false, onTap: () {}),
              _buildConnectionCard(context: context, logoAsset: 'assets/logos/metamask_logo.png', name: 'MetaMask (ETH/BSC/etc)', isConnected: false, onTap: () {}),
              _buildConnectionCard(context: context, logoAsset: 'assets/logos/trust_wallet_logo.png', name: 'Trust Wallet', isConnected: false, onTap: () {}),
              _buildConnectionCard(context: context, logoAsset: 'assets/logos/safepal_logo.png', name: 'SafePal', isConnected: false, onTap: () {}),
              _buildConnectionCard(context: context, logoAsset: 'assets/logos/exodus_logo.png', name: 'Exodus', isConnected: false, onTap: () {}),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard({
    required BuildContext context,
    required String logoAsset,
    required String name,
    required bool isConnected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Image.asset(logoAsset, width: 80, height: 80, errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_center, size: 40)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(isConnected ? 'Conectado' : 'No conectado', style: TextStyle(color: isConnected ? Colors.green : Colors.red)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}