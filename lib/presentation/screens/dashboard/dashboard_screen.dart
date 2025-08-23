// lib/presentation/screens/dashboard/dashboard_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/analysis/fiat_analysis_screen.dart';
// --- ¡IMPORTAMOS LA PANTALLA DE CONEXIONES! ---
import 'package:cpm/presentation/screens/connections/connections_screen.dart'; 
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/swap_dialog_widget.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/fiat_dialog_widget.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/portfolio_summary_card.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<PortfolioAsset> _myPortfolio = [];
  List<CryptoCoin> _marketPrices = [];
  bool _isLoading = true;
  StreamSubscription? _transactionsSubscription;
  List<Transaction> _allTransactions = []; 

  PortfolioSummary _summary = PortfolioSummary(
    totalInvested: 0, currentValue: 0, totalPnlUSD: 0, totalPnlPercent: 0, recoveredFromSales: 0,
    totalInvestedByFiat: {}, totalRecoveredByFiat: {}
  );

  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (mounted) setState(() => _isLoading = true);
    await _loadMarketData();
    _listenToPortfolioChanges();
  }

  Future<void> _loadMarketData() async {
    try {
      final marketData = await ApiService.getCoins();
      if (mounted) setState(() => _marketPrices = marketData);
    } catch (e) {
      print("Error al cargar datos del mercado: $e");
    }
  }
  
  void _listenToPortfolioChanges() {
    _transactionsSubscription?.cancel();
    _transactionsSubscription = FirestoreService.getTransactionsStream().listen((transactions) {
      print("Nuevos datos de transacciones recibidos (${transactions.length}).");
      
      try {
        final portfolio = PortfolioCalculator.calculate(transactions, _marketPrices);
        final summary = PortfolioCalculator.calculateSummary(
          portfolio: portfolio,
          transactions: transactions,
          marketPrices: _marketPrices,
        );

        if (mounted) {
          setState(() {
            _allTransactions = transactions;
            _myPortfolio = portfolio;
            _summary = summary;
            if (_isLoading) _isLoading = false;
          });
        }
      } catch (e, stackTrace) {
        print("!!!!!! ERROR ATRAPADO DURANTE EL CÁLCULO DEL PORTAFOLIO !!!!!!");
        print("!!!!!! ERROR: $e");
        print("!!!!!! STACK TRACE: $stackTrace");
      }
    });
  }

  void _showSwapDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SwapDialog(
        myPortfolio: _myPortfolio,
        marketPrices: _marketPrices,
      ),
    );
  }
  
  void _showFiatDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FiatDialog(
        marketPrices: _marketPrices,
        onTransactionAdded: (transaction) {
          // El Stream se encarga de refrescar
        },
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Portafolio'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          // --- ¡AQUÍ ESTÁ EL BOTÓN QUE FALTABA! ---
          IconButton(
            icon: const Icon(Icons.sync_alt),
            tooltip: 'Conexiones',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConnectionsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Análisis de Fiat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FiatAnalysisScreen(transactions: _allTransactions),
                ),
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
            onRefresh: _initializeData,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: PortfolioSummaryCard(
                    totalInvested: _summary.totalInvested,
                    currentValue: _summary.currentValue,
                    totalPnlUSD: _summary.totalPnlUSD,
                    totalPnlPercent: _summary.totalPnlPercent,
                    recoveredFromSales: _summary.recoveredFromSales,
                  ),
                ),
                if (_myPortfolio.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Tu portafolio está vacío.\n¡Añade tu primera transacción!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _initializeData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refrescar'),
                          )
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final asset = _myPortfolio[index];
                        final marketCoin = _marketPrices.firstWhere(
                          (coin) => coin.id.toLowerCase() == asset.coinId.toLowerCase(),
                          orElse: () => CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0),
                        );
                        return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
                      },
                      childCount: _myPortfolio.length,
                    ),
                  ),
              ],
            ),
          ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _showFiatDialog,
            label: const Text('Fiat'),
            icon: const Icon(Icons.attach_money),
            heroTag: 'fiat_fab',
            backgroundColor: Colors.blue,
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            onPressed: _showSwapDialog,
            label: const Text('Swap'),
            icon: const Icon(Icons.swap_horiz),
            heroTag: 'swap_fab',
            backgroundColor: Colors.purple,
          ),
        ],
      ),
    );
  }
}