// lib/presentation/screens/dashboard/dashboard_screen.dart

import 'dart:async';
import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/models/summary_models.dart'; // ¡IMPORT RESTAURADO!
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/analysis/fiat_analysis_screen.dart';
import 'package:cpm/presentation/screens/connections/accounts_screen.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/portfolio_summary_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const List<String> _fiatTickers = ['COP', 'USD', 'EUR'];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<app_models.PortfolioAsset> _myPortfolio = [];
  List<app_models.PortfolioAsset> _fiatHoldings = [];
  PortfolioSummary _summary = PortfolioSummary(
    totalInvested: 0, currentValue: 0, totalPnlUSD: 0, totalPnlPercent: 0, 
    recoveredFromSales: 0, totalInvestedByFiat: {}, totalRecoveredByFiat: {}
  );
  bool _isLoading = true;
  StreamSubscription? _transactionsSubscription;
  
  final List<app_models.CryptoCoin> _marketPrices = [];

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
        final finalPortfolio = await PortfolioCalculator.calculate(
          allTransactions: transactions, 
          marketPrices: []
        );

        final summary = await PortfolioCalculator.calculateSummary(
          allTransactions: transactions, 
          marketPrices: []
        );
        
        final cryptoAssets = <app_models.PortfolioAsset>[];
        final fiatAssets = <app_models.PortfolioAsset>[];

        for (final asset in finalPortfolio) {
          if (_fiatTickers.contains(asset.ticker.toUpperCase())) {
            fiatAssets.add(asset);
          } else {
            cryptoAssets.add(asset);
          }
        }
        
        cryptoAssets.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        
        if (mounted) {
          setState(() {
            _myPortfolio = cryptoAssets;
            _fiatHoldings = fiatAssets;
            _summary = summary;
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
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Análisis Fiat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FiatAnalysisScreen(
                  fiatHoldings: _fiatHoldings,
                  totalInvestedByFiat: _summary.totalInvestedByFiat,
                  totalRecoveredByFiat: _summary.totalRecoveredByFiat,
                )),
              );
            },
          ),
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
                        final marketCoin = app_models.CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0);
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