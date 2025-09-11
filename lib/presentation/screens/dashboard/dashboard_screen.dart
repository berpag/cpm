// lib/presentation/screens/dashboard/dashboard_screen.dart

import 'dart:async';
import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/models/summary_models.dart'; // ¡IMPORT CORREGIDO!
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/connections/accounts_screen.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/portfolio_summary_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<app_models.PortfolioAsset> _myPortfolio = [];
  PortfolioSummary _summary = PortfolioSummary(
    totalInvested: 0, currentValue: 0, totalPnlUSD: 0, totalPnlPercent: 0, 
    recoveredFromSales: 0, totalInvestedByFiat: {}, totalRecoveredByFiat: {}
  );
  bool _isLoading = true;
  StreamSubscription? _transactionsSubscription;
  
  List<app_models.CryptoCoin> _marketPrices = [];

  @override
  void initState() {
    super.initState();
    _listenToPortfolioChanges();
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _listenToPortfolioChanges() async {
    if (mounted) setState(() => _isLoading = true);
    
    _transactionsSubscription?.cancel();
    _transactionsSubscription = FirestoreService.getTransactionsStream().listen((transactions) async {
      if (!mounted) return;
      try {
        final coinIds = transactions.map((tx) => tx.cryptoCoinId).toSet().toList();
        final marketPrices = await ApiService.getMarketDataForIds(coinIds);
        
        final finalPortfolio = await PortfolioCalculator.calculate(
          allTransactions: transactions, 
          marketPrices: marketPrices
        );

        // --- ¡LÓGICA SIMPLIFICADA Y CORREGIDA! ---
        final summary = await PortfolioCalculator.calculateSummary(
          allTransactions: transactions, 
          marketPrices: marketPrices
        );
        
        finalPortfolio.sort((a, b) => 
            (b.totalAmount * (marketPrices.firstWhere((c) => c.id == b.coinId, orElse: () => app_models.CryptoCoin(price: 0.0, id: '', name: '', ticker: '')).price))
            .compareTo(a.totalAmount * (marketPrices.firstWhere((c) => c.id == a.coinId, orElse: () => app_models.CryptoCoin(price: 0.0, id: '', name: '', ticker: '')).price))
        );
        
        if (mounted) {
          setState(() {
            _myPortfolio = finalPortfolio;
            _summary = summary;
            _marketPrices = marketPrices; 
            _isLoading = false;
          });
        }
      } catch (e) {
        print("Error en el flujo de actualización del dashboard: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Portafolio Global'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Cuentas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AccountsScreen(
                  marketPrices: _marketPrices,
                )),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : RefreshIndicator(
            onRefresh: _listenToPortfolioChanges,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: PortfolioSummaryCard(
                    totalInvested: _summary.totalInvested, currentValue: _summary.currentValue,
                    totalPnlUSD: _summary.totalPnlUSD, totalPnlPercent: _summary.totalPnlPercent,
                    recoveredFromSales: _summary.recoveredFromSales,
                  ),
                ),
                if (_myPortfolio.isEmpty)
                  const SliverFillRemaining(child: Center(child: Text('Tu portafolio está vacío.')))
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final asset = _myPortfolio[index];
                        final marketCoin = _marketPrices.firstWhere(
                          (c) => c.id == asset.coinId,
                          orElse: () => app_models.CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0)
                        );
                        return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
                      },
                      childCount: _myPortfolio.length,
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}