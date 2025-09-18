// lib/presentation/screens/dashboard/dashboard_screen.dart

import 'dart:async';
import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/analysis/fiat_analysis_screen.dart';
import 'package:cpm/presentation/screens/connections/accounts_screen.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/portfolio_summary_card.dart';
import 'package:cpm/presentation/screens/settings/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DashboardData {
  final List<app_models.PortfolioAsset> cryptoAssets;
  final List<app_models.PortfolioAsset> fiatHoldings;
  final List<app_models.CryptoCoin> marketPrices;
  final PortfolioSummary summary;

  DashboardData({
    required this.cryptoAssets,
    required this.fiatHoldings,
    required this.marketPrices,
    required this.summary,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  Stream<DashboardData>? _dashboardStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardStream = _getDashboardDataStream();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  void _refreshData() {
    setState(() {
      _dashboardStream = _getDashboardDataStream();
    });
  }

  Stream<DashboardData> _getDashboardDataStream() {
    return Stream.fromFuture(_fetchDashboardData());
  }

  Future<DashboardData> _fetchDashboardData() async {
    final allTransactions = await FirestoreService.getTransactionsStream().first;
    final calculatedData = await FirestoreService.getCalculatedPortfolioStream().first;
    final fiatTickers = await FirestoreService.getFiatListStream().first;
    final portfolioWithBalances = await PortfolioCalculator.calculate(allTransactions: allTransactions, marketPrices: []);
    final coinIdsToFetch = portfolioWithBalances.map((a) => a.coinId).toSet().toList();
    final marketPrices = await ApiService.getMarketDataForIds(coinIdsToFetch);
    _consolidateAndCalculateAverages(portfolioWithBalances, calculatedData);
    final summary = await PortfolioCalculator.calculateSummary(allTransactions: allTransactions, marketPrices: marketPrices);
    final cryptoAssets = portfolioWithBalances.where((asset) => !fiatTickers.contains(asset.ticker.toUpperCase())).toList();
    final fiatHoldings = portfolioWithBalances.where((asset) => fiatTickers.contains(asset.ticker.toUpperCase())).toList();
    cryptoAssets.sort((a, b) {
      final priceA = marketPrices.firstWhere((p) => p.id == a.coinId, orElse: () => app_models.CryptoCoin(price: 0.0, id: '', name: '', ticker: '')).price;
      final priceB = marketPrices.firstWhere((p) => p.id == b.coinId, orElse: () => app_models.CryptoCoin(price: 0.0, id: '', name: '', ticker: '')).price;
      final valueA = a.totalAmount * priceA;
      final valueB = b.totalAmount * priceB;
      return valueB.compareTo(valueA);
    });
    return DashboardData(cryptoAssets: cryptoAssets, fiatHoldings: fiatHoldings, marketPrices: marketPrices, summary: summary);
  }

  void _consolidateAndCalculateAverages(
    List<app_models.PortfolioAsset> portfolioFromAllSources,
    Map<String, Map<String, dynamic>> calculatedData
  ) {
    for (var asset in portfolioFromAllSources) {
      final binanceData = calculatedData['Binance_${asset.coinId}'];
      final manualData = calculatedData['Manual_${asset.coinId}'];
      double totalInvested = 0;
      double totalAmountForAvg = 0;
      if (binanceData != null) {
        final invested = (binanceData['totalInvestedUSD'] as num?)?.toDouble() ?? 0.0;
        final avgPrice = (binanceData['averageBuyPrice'] as num?)?.toDouble() ?? 0.0;
        final amount = avgPrice > 0 ? invested / avgPrice : 0.0;
        totalInvested += invested;
        totalAmountForAvg += amount;
      }
      if (manualData != null) {
        final invested = (manualData['totalInvestedUSD'] as num?)?.toDouble() ?? 0.0;
        final avgPrice = (manualData['averageBuyPrice'] as num?)?.toDouble() ?? 0.0;
        final amount = avgPrice > 0 ? invested / avgPrice : 0.0;
        totalInvested += invested;
        totalAmountForAvg += amount;
      }
      asset.totalInvestedUSD = totalInvested;
      asset.averageBuyPrice = totalAmountForAvg > 0 ? totalInvested / totalAmountForAvg : 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DashboardData>(
        stream: _dashboardStream,
        builder: (context, snapshot) {
          // --- MOSTRAR LOADER MIENTRAS NO HAYA DATOS ---
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error al cargar datos: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No hay datos disponibles."));
          }

          final data = snapshot.data!;

          // --- CONSTRUIMOS EL SCAFFOLD UNA SOLA VEZ, CON LOS DATOS YA LISTOS ---
          return Scaffold(
             appBar: AppBar(
              title: const Text('Mi Portafolio Global'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              actions: [
                IconButton(icon: const Icon(Icons.analytics_outlined), tooltip: 'Análisis Fiat', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FiatAnalysisScreen(fiatHoldings: data.fiatHoldings, totalInvestedByFiat: data.summary.totalInvestedByFiat, totalRecoveredByFiat: data.summary.totalRecoveredByFiat)))),
                IconButton(icon: const Icon(Icons.account_balance_wallet_outlined), tooltip: 'Cuentas', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AccountsScreen(marketPrices: data.marketPrices)))),
                IconButton(icon: const Icon(Icons.settings), tooltip: 'Configuración', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
                IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar Sesión', onPressed: () => FirebaseAuth.instance.signOut()),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async => _refreshData(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: PortfolioSummaryCard(summary: data.summary)),
                  if (data.cryptoAssets.isEmpty)
                    const SliverFillRemaining(child: Center(child: Text('Tu portafolio está vacío.')))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final asset = data.cryptoAssets[index];
                          final marketCoin = data.marketPrices.firstWhere((c) => c.id == asset.coinId, orElse: () => app_models.CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0));
                          return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
                        },
                        childCount: data.cryptoAssets.length,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}