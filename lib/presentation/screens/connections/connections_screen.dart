// lib/presentation/screens/connections/connections_screen.dart

import 'package:flutter/material.dart';
import 'package:cpm/presentation/screens/connections/widgets/api_key_dialog.dart';
import 'package:cpm/data/services/binance_api_service.dart';
import 'package:cpm/data/services/firestore_service.dart'; 

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  bool _isLoading = false;

  Future<void> _showApiKeyDialog(String exchangeName) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ApiKeyDialog(exchangeName: exchangeName),
    );

    if (result != null) {
      final apiKey = result['apiKey']!;
      final secretKey = result['secretKey']!;
      
      setState(() => _isLoading = true);
      
      try {
        await BinanceApiService.getAccountInfo(apiKey: apiKey, secretKey: secretKey);
        await FirestoreService.saveApiKey(
          exchangeName: exchangeName,
          apiKey: apiKey,
          secretKey: secretKey,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('¡$exchangeName conectado con éxito!'), backgroundColor: Colors.green),
          );
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al conectar: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
  
  void _showAddressDialog(String walletName) {
    print('Añadir dirección para $walletName');
    // TODO: Implementar diálogo para direcciones
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Cuentas'),
        backgroundColor: const Color(0xFF1a237e),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // --- CONTENIDO DEL LISTVIEW RESTAURADO ---
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
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/binance_logo.png',
                name: 'Binance',
                isConnected: false,
                onTap: () => _showApiKeyDialog('Binance'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/coinex_logo.png',
                name: 'CoinEx',
                isConnected: false,
                onTap: () => _showApiKeyDialog('CoinEx'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/bybit_logo.png',
                name: 'Bybit',
                isConnected: false,
                onTap: () => _showApiKeyDialog('Bybit'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/bingx_logo.png',
                name: 'BingX',
                isConnected: false,
                onTap: () => _showApiKeyDialog('BingX'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/mexc_logo.png',
                name: 'MEXC',
                isConnected: false,
                onTap: () => _showApiKeyDialog('MEXC'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/bitget_logo.png',
                name: 'Bitget',
                isConnected: false,
                onTap: () => _showApiKeyDialog('Bitget'),
              ),
              
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
              
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/phantom_logo.png',
                name: 'Phantom (Solana)',
                isConnected: false,
                onTap: () => _showAddressDialog('Phantom'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/metamask_logo.png',
                name: 'MetaMask (ETH/BSC/etc)',
                isConnected: false,
                onTap: () => _showAddressDialog('MetaMask'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/trust_wallet_logo.png',
                name: 'Trust Wallet',
                isConnected: false,
                onTap: () => _showAddressDialog('Trust Wallet'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/safepal_logo.png',
                name: 'SafePal',
                isConnected: false,
                onTap: () => _showAddressDialog('SafePal'),
              ),
              _buildConnectionCard(
                context: context,
                logoAsset: 'assets/logos/exodus_logo.png',
                name: 'Exodus',
                isConnected: false,
                onTap: () => _showAddressDialog('Exodus'),
              ),
            ],
          ),
          // ------------------------------------------
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
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
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Image.asset(
          logoAsset,
          width: 80,
          height: 80,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_center, size: 40)
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(isConnected ? 'Conectado' : 'No conectado', style: TextStyle(color: isConnected ? Colors.green : Colors.red)),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}