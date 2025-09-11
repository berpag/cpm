// lib/presentation/screens/connections/accounts_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/account_detail/binance_detail_screen.dart'; // ¡Referencia actualizada!
import 'package:cpm/presentation/screens/account_detail/manual_account_detail_screen.dart';

class Account {
  final String name;
  final String logoAsset;
  final String type;

  Account({required this.name, required this.logoAsset, required this.type});
}

class AccountsScreen extends StatefulWidget {
  final List<app_models.CryptoCoin> marketPrices;

  const AccountsScreen({
    super.key,
    required this.marketPrices,
  });

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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildAccountList(context, {}); // Pasamos mapa vacío
          }

          final transactions = snapshot.data!;
          
          // --- ¡CAMBIO! USAMOS UN FUTUREBUILDER PARA EL CÁLCULO ASÍNCRONO ---
          // Calculamos el portafolio completo una sola vez
          return FutureBuilder<List<app_models.PortfolioAsset>>(
            future: PortfolioCalculator.calculate(
              allTransactions: transactions, 
              marketPrices: widget.marketPrices
            ),
            builder: (context, portfolioSnapshot) {
              if (portfolioSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (portfolioSnapshot.hasError) {
                return Center(child: Text('Error al calcular: ${portfolioSnapshot.error}'));
              }

              final fullPortfolio = portfolioSnapshot.data ?? [];
              final accountValues = <String, double>{};

              // Agrupamos los activos por su fuente y calculamos el valor total
              for (final asset in fullPortfolio) {
                final source = asset.sourceAccount; // Asumimos que PortfolioAsset tendrá sourceAccount
                final marketCoin = widget.marketPrices.firstWhere((c) => c.id == asset.coinId, orElse: () => app_models.CryptoCoin(price: 0.0, id: '', name: '', ticker: ''));
                final assetValue = asset.totalAmount * marketCoin.price;
                accountValues.update(source, (value) => value + assetValue, ifAbsent: () => assetValue);
              }

              return _buildAccountList(context, accountValues);
            },
          );
        },
      ),
    );
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BinanceDetailScreen( // ¡Referencia actualizada!
              accountName: account.name,
              marketPrices: widget.marketPrices,
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ManualAccountDetailScreen(
              marketPrices: widget.marketPrices,
            ))),
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

  // --- TARJETA DE CUENTA REFACTORIZADA PARA SER MÁS GENÉRICA ---
  Widget _buildAccountCard({
    required BuildContext context,
    required Account account,
    required double value,
    required VoidCallback onTap,
  }) {
    final formatCurrency = NumberFormat.currency(locale: 'en_US', symbol: '\$');

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