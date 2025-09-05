// lib/presentation/screens/connections/accounts_screen.dart

import 'package:flutter/material.dart';
import 'package:cpm/presentation/screens/account_detail/account_detail_screen.dart';

// Un modelo simple para representar una cuenta. Facilita la gestión.
class Account {
  final String name;
  final String logoAsset;
  final String type; // 'Exchange' o 'Wallet'

  Account({
    required this.name,
    required this.logoAsset,
    required this.type,
  });
}

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  // Por ahora, definimos las cuentas de forma estática.
  // Más adelante, esto podría venir de Firestore.
  final List<Account> _accounts = [
    Account(name: 'Binance', logoAsset: 'assets/logos/binance_logo.png', type: 'Exchange'),
    Account(name: 'Phantom', logoAsset: 'assets/logos/phantom_logo.png', type: 'Wallet'),
    // Añadimos una "cuenta" para las transacciones manuales que no pertenecen a ningún sitio.
    Account(name: 'Transacciones Manuales', logoAsset: 'assets/logos/manual_logo.png', type: 'Manual'), 
  ];

  @override
  Widget build(BuildContext context) {
    // Agrupamos las cuentas por tipo para mostrarlas en secciones separadas
    final exchanges = _accounts.where((acc) => acc.type == 'Exchange').toList();
    final wallets = _accounts.where((acc) => acc.type == 'Wallet').toList();
    final manuals = _accounts.where((acc) => acc.type == 'Manual').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Cuentas'),
        backgroundColor: const Color(0xFF1a237e),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context, 'Exchanges'),
          ...exchanges.map((account) => _buildAccountCard(context, account)),
          
          const Divider(height: 48, thickness: 1),

          _buildSectionTitle(context, 'Wallets'),
          ...wallets.map((account) => _buildAccountCard(context, account)),

          const Divider(height: 48, thickness: 1),
          
          _buildSectionTitle(context, 'Otros'),
          ...manuals.map((account) => _buildAccountCard(context, account)),
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

  Widget _buildAccountCard(BuildContext context, Account account) {
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
          // Un fallback por si el logo no se encuentra
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_center, size: 40)
        ),
        title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: const Text(
          // TODO: Reemplazar con el cálculo del balance real de la cuenta
          '\$0.00', 
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AccountDetailScreen(accountName: account.name),
            ),
          );
        },
      ),
    );
  }
}