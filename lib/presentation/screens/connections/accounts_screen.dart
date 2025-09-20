// lib/presentation/screens/connections/accounts_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/account_detail/binance_detail_screen.dart';
import 'package:cpm/presentation/screens/account_detail/manual_account_detail_screen.dart';

class Account {
  final String name;
  final String logoAsset;
  final String type;

  Account({required this.name, required this.logoAsset, required this.type});
}

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final List<Account> _accounts = [
    Account(name: 'Binance', logoAsset: 'assets/logos/binance_logo.png', type: 'Exchange'),
    Account(name: 'Phantom', logoAsset: 'assets/logos/phantom_logo.png', type: 'Wallet'),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Cuentas y Entradas'),
        backgroundColor: const Color(0xFF1a237e),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<app_models.Transaction>>(
        stream: FirestoreService.getTransactionsStream(),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allTransactions = transactionSnapshot.data ?? [];
          
          return StreamBuilder<Map<String, Map<String, dynamic>>>(
            stream: FirestoreService.getCalculatedPortfolioStream(),
            builder: (context, calculatedDataSnapshot) {
              if (calculatedDataSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final calculatedData = calculatedDataSnapshot.data ?? {};

              // --- CAMBIO IMPORTANTE: La lógica de cálculo ahora está en una función separada ---
              // Esto hace que el FutureBuilder sea más limpio y eficiente.
              return FutureBuilder<Map<String, double>>(
                future: _calculateAccountValues(allTransactions, calculatedData),
                builder: (context, valuesSnapshot) {
                  if (valuesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final accountValues = valuesSnapshot.data ?? {};
                  return _buildAccountList(context, accountValues);
                },
              );
            },
          );
        },
      ),
    );
  }
  
  // --- NUEVA FUNCIÓN ASÍNCRONA PARA CALCULAR LOS VALORES ---
  Future<Map<String, double>> _calculateAccountValues(
    List<app_models.Transaction> allTransactions,
    Map<String, Map<String, dynamic>> calculatedData,
  ) async {
    final accountValues = <String, double>{};
    
    // Obtenemos los saldos de cada cuenta por separado
    final binancePortfolio = await PortfolioCalculator.calculate(allTransactions: allTransactions, marketPrices: [], sourceAccount: 'Binance');
    final manualPortfolio = await PortfolioCalculator.calculate(allTransactions: allTransactions, marketPrices: [], sourceAccount: 'Manual');
    
    // Concatenamos las listas de portafolios
    final fullPortfolio = [...binancePortfolio, ...manualPortfolio];
    
    // Ahora iteramos sobre los activos con saldo y buscamos su precio en la caché
    for (final asset in fullPortfolio) {
      final source = asset.sourceAccount;
      final docId = '${source}_${asset.coinId}';
      
      final priceFromCache = (calculatedData[docId]?['currentPrice'] as num?)?.toDouble() ?? 0.0;
      final assetValue = asset.totalAmount * priceFromCache;
      
      // Actualizamos el mapa de valores totales por cuenta
      accountValues.update(source, (value) => value + assetValue, ifAbsent: () => assetValue);
    }

    return accountValues;
  }

  Widget _buildAccountList(BuildContext context, Map<String, double> accountValues) {
    final exchanges = _accounts.where((acc) => acc.type == 'Exchange').toList();
    final wallets = _accounts.where((acc) => acc.type == 'Wallet').toList();

    return RefreshIndicator(
      onRefresh: () async => setState((){}),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context, 'Exchanges'),
          ...exchanges.map((account) => _buildAccountCard(
            context: context, 
            account: account, 
            value: accountValues[account.name] ?? 0.0,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BinanceDetailScreen(
              accountName: account.name,
            ))),
          )),
          
          const Divider(height: 48, thickness: 1),

          _buildSectionTitle(context, 'Wallets'),
          ...wallets.map((account) => _buildAccountCard(
            context: context, 
            account: account, 
            value: accountValues[account.name] ?? 0.0,
            onTap: () { /* TODO: Navegar a la pantalla de detalle de la wallet */ }
          )),

          const Divider(height: 48, thickness: 1),
          
          _buildSectionTitle(context, 'Entradas Manuales'),
          
          _buildAccountCard(
            context: context,
            account: Account(name: 'Entradas Manuales', logoAsset: 'assets/logos/manual_logo.png', type: 'Manual'),
            value: accountValues['Manual'] ?? 0.0,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManualAccountDetailScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAccountCard({
    required BuildContext context,
    required Account account,
    required double value,
    required VoidCallback onTap,
  }) {
    // --- CAMBIO: Nuevo formateador con hasta 4 decimales ---
    final formatCurrency = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 4);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        leading: Image.asset(
          account.logoAsset,
          width: 40,
          height: 40,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_center, size: 40)
        ),
        title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(
          formatCurrency.format(value), 
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}