// lib/presentation/screens/connections/connections_screen.dart

import 'package:flutter/material.dart';
import 'package:cpm/presentation/screens/connections/widgets/api_key_dialog.dart';
import 'package:cpm/data/services/binance_api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
// --- ¡NUEVO IMPORT! ---
import 'package:cpm/presentation/screens/connections/binance_options_screen.dart';


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

  // --- LAS FUNCIONES DE SYNC E IMPORT SE MOVERÁN A 'binance_options_screen.dart' ---

  @override
  Widget build(BuildContext context) {
    final connectedExchangeNames = _activeConnections.map((c) => c.exchangeName.toLowerCase()).toList();

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
              Text('Exchanges Centralizados', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Conecta tus cuentas para sincronizar tus balances e historial de trades.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              
              // --- LÓGICA DE CONSTRUCCIÓN DE TARJETAS MODIFICADA ---
              ..._supportedExchanges.map((name) {
                final isConnected = connectedExchangeNames.contains(name.toLowerCase());
                
                if (name == 'Binance') {
                  final binanceConnection = isConnected 
                    ? _activeConnections.firstWhere((c) => c.exchangeName.toLowerCase() == 'binance')
                    : null;
                  
                  return _buildConnectionCard(
                    context: context,
                    logoAsset: 'assets/logos/binance_logo.png',
                    name: 'Binance',
                    isConnected: isConnected,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BinanceOptionsScreen(binanceConnection: binanceConnection)),
                      ).then((_) => _loadConnections()); // Recargamos al volver
                    },
                  );
                } else {
                  // Para otros exchanges, mantenemos la lógica antigua por ahora
                  return _buildConnectionCard(
                    context: context,
                    logoAsset: 'assets/logos/${name.toLowerCase()}_logo.png',
                    name: name,
                    isConnected: isConnected,
                    onTap: () => isConnected ? null : _showApiKeyDialog(name),
                  );
                }
              }),

              const Divider(height: 48, thickness: 1),
              Text('Wallets Descentralizadas', style: Theme.of(context).textTheme.titleLarge),
              // ... El resto de la UI no cambia ...
              const SizedBox(height: 8),
              const Text(
                'Añade tus direcciones públicas para rastrear tus activos directamente en la blockchain.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildConnectionCard(context: context, logoAsset: 'assets/logos/phantom_logo.png', name: 'Phantom (Solana)', isConnected: false, onTap: () {}),
              _buildConnectionCard(context: context, logoAsset: 'assets/logos/metamask_logo.png', name: 'MetaMask (ETH/BSC/etc)', isConnected: false, onTap: () {}),
            ],
          ),
          if (_isLoading)
            Container( // ... El loader no cambia ...
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_loadingMessage, style: const TextStyle(color: Colors.white, fontSize: 16)),
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
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    // ... El widget de la tarjeta no cambia ...
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Image.asset(logoAsset, width: 40, height: 40, errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_center, size: 40)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(isConnected ? 'Conectado' : 'No conectado', style: TextStyle(color: isConnected ? Colors.green : Colors.red)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}