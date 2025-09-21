
// lib/presentation/screens/dashboard/dashboard_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/models/summary_models.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/analysis/fiat_analysis_screen.dart';
import 'package:cpm/presentation/screens/connections/accounts_screen.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/portfolio_summary_card.dart';
import 'package:cpm/presentation/screens/settings/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// --- CAMBIO: Se elimina 'marketPrices' del modelo ---
class DashboardData {
  final List<app_models.PortfolioAsset> cryptoAssets;
  final List<app_models.PortfolioAsset> fiatHoldings;
  final PortfolioSummary summary;
  final Map<String, app_models.CryptoCoin> marketPrices; // Mantenemos los precios para pasarlos a las tarjetas

  DashboardData({
    required this.cryptoAssets,
    required this.fiatHoldings,
    required this.summary,
    required this.marketPrices,
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

  // --- CAMBIO: El Stream ahora reacciona a cambios en transacciones Y en la caché de precios ---
  Stream<DashboardData> _getDashboardDataStream() {
    // Escuchamos a ambos streams. Si cualquiera de los dos cambia, recalculamos todo.
    // Esto asegura que si el usuario actualiza precios en una pantalla de detalle,
    // el dashboard lo reflejará inmediatamente.
    // (Una implementación con rxdart's CombineLatestStream sería aún más óptima)
    return Stream.multi((controller) {
      final sub1 = FirestoreService.getTransactionsStream().listen((_) => _fetchDashboardData().then(controller.add));
      final sub2 = FirestoreService.getCalculatedPortfolioStream().listen((_) => _fetchDashboardData().then(controller.add));
      controller.onCancel = () {
        sub1.cancel();
        sub2.cancel();
      };
    });
  }

  // --- CAMBIO: Lógica de fetch completamente refactorizada. NO llama a APIs externas ---
  Future<DashboardData> _fetchDashboardData() async {
    // 1. Obtener todos los datos necesarios de Firestore
    final results = await Future.wait([
      FirestoreService.getTransactionsStream().first,
      FirestoreService.getCalculatedPortfolioStream().first,
      FirestoreService.getFiatListStream().first,
    ]);

    final allTransactions = results[0] as List<app_models.Transaction>;
    final calculatedData = results[1] as Map<String, Map<String, dynamic>>;
    final fiatTickers = results[2] as Set<String>;

    // 2. Calcular los saldos consolidados de todas las cuentas
    final portfolioWithBalances = await PortfolioCalculator.calculate(allTransactions: allTransactions, marketPrices: []);

    // 3. "Enriquecer" el portafolio consolidado con los datos de la caché (costos y precios)
    final Map<String, app_models.CryptoCoin> marketPrices = {}; 
    _consolidateAndEnrichData(portfolioWithBalances, calculatedData, marketPrices);

    // 4. Calcular el resumen final usando los datos ya enriquecidos
    final summary = _calculateSummaryFromEnrichedPortfolio(portfolioWithBalances, allTransactions, marketPrices);

    final cryptoAssets = portfolioWithBalances.where((asset) => !fiatTickers.contains(asset.ticker.toUpperCase())).toList();
    final fiatHoldings = portfolioWithBalances.where((asset) => fiatTickers.contains(asset.ticker.toUpperCase())).toList();

    // 5. Ordenar por valor de mercado actual (usando precios de la caché)
    cryptoAssets.sort((a, b) {
      final priceA = marketPrices[a.coinId]?.price ?? 0.0;
      final priceB = marketPrices[b.coinId]?.price ?? 0.0;
      final valueA = a.totalAmount * priceA;
      final valueB = b.totalAmount * priceB;
      return valueB.compareTo(valueA);
    });

    return DashboardData(cryptoAssets: cryptoAssets, fiatHoldings: fiatHoldings, summary: summary, marketPrices: marketPrices);
  }

  // --- CAMBIO: La función ahora también extrae precios y enriquece el portafolio ---
  void _consolidateAndEnrichData(
    List<app_models.PortfolioAsset> consolidatedPortfolio,
    Map<String, Map<String, dynamic>> calculatedDataFromAllSources,
    Map<String, app_models.CryptoCoin> marketPrices,
  ) {
    for (var asset in consolidatedPortfolio) {
      final sourcesData = calculatedDataFromAllSources.entries
          .where((entry) => entry.key.endsWith('_${asset.coinId}'));

      double totalInvested = 0;
      double totalAmountForAvg = 0;
      double latestPrice = 0;
      Timestamp? latestTimestamp;

      for (var sourceEntry in sourcesData) {
        final sourceMap = sourceEntry.value;
        final invested = (sourceMap['totalInvestedUSD'] as num?)?.toDouble() ?? 0.0;
        final avgPrice = (sourceMap['averageBuyPrice'] as num?)?.toDouble() ?? 0.0;
        
        final amount = avgPrice > 0 ? invested / avgPrice : 0.0;
        totalInvested += invested;
        totalAmountForAvg += amount;

        final price = (sourceMap['currentPrice'] as num?)?.toDouble();
        final timestamp = sourceMap['lastPriceUpdate'] as Timestamp?;
        if (price != null && timestamp != null) {
          if (latestTimestamp == null || timestamp.compareTo(latestTimestamp) > 0) {
            latestTimestamp = timestamp;
            latestPrice = price;
          }
        }
      }

      asset.totalInvestedUSD = totalInvested;
      asset.averageBuyPrice = totalAmountForAvg > 0 ? totalInvested / totalAmountForAvg : 0.0;

      if (latestTimestamp != null) {
        marketPrices[asset.coinId] = app_models.CryptoCoin(
            id: asset.coinId, name: asset.name, ticker: asset.ticker, price: latestPrice);
      }
    }
  }

  // --- NUEVA FUNCIÓN: Para calcular el resumen directamente ---
  PortfolioSummary _calculateSummaryFromEnrichedPortfolio(
    List<app_models.PortfolioAsset> enrichedPortfolio,
    List<app_models.Transaction> allTransactions,
    Map<String, app_models.CryptoCoin> marketPrices,
  ) {
    double currentPortfolioValue = 0, totalPortfolioInvested = 0;

    for (var asset in enrichedPortfolio) {
      totalPortfolioInvested += asset.totalInvestedUSD;
      final price = marketPrices[asset.coinId]?.price ?? 0.0;
      currentPortfolioValue += asset.totalAmount * price;
    }

    final Map<String, double> investedByFiat = {}, recoveredByFiat = {};
    for (var tx in allTransactions) {
      if (tx.fiatCurrency != null && tx.fiatAmount != null) {
        if (tx.type.contains('Buy')) {
          investedByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
        } else if (tx.type.contains('Sell')) {
          recoveredByFiat.update(tx.fiatCurrency!, (value) => value + tx.fiatAmount!, ifAbsent: () => tx.fiatAmount!);
        }
      }
    }

    final recoveredInUSD = allTransactions
        .where((tx) => tx.type.contains('Sell'))
        .fold<double>(0.0, (sum, tx) => sum + (tx.usdValue ?? tx.fiatAmount ?? 0.0));
    
    final pnlUSD = (currentPortfolioValue + recoveredInUSD) - totalPortfolioInvested;
    final pnlPercent = totalPortfolioInvested > 0 ? (pnlUSD / totalPortfolioInvested) * 100 : 0.0;
    
    return PortfolioSummary(
      totalInvested: totalPortfolioInvested, 
      currentValue: currentPortfolioValue,
      recoveredFromSales: recoveredInUSD, 
      totalPnlUSD: pnlUSD,
      totalPnlPercent: pnlPercent, 
      totalInvestedByFiat: investedByFiat,
      totalRecoveredByFiat: recoveredByFiat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DashboardData>(
        stream: _dashboardStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error al cargar datos: ${snapshot.error}"));
          }
          if (!snapshot.hasData || (snapshot.data!.cryptoAssets.isEmpty && snapshot.data!.fiatHoldings.isEmpty)) {
            // Scaffold para mostrar el AppBar incluso si no hay datos
            return Scaffold(
              appBar: _buildAppBar(null),
              body: const Center(child: Text("Añade tu primera transacción o importa tus datos desde Cuentas.")),
            );
          }

          final data = snapshot.data!;

          return Scaffold(
             appBar: _buildAppBar(data),
            body: RefreshIndicator(
              onRefresh: () async => _refreshData(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: PortfolioSummaryCard(summary: data.summary)),
                  if (data.cryptoAssets.isEmpty)
                    const SliverFillRemaining(child: Center(child: Text('Tu portafolio de criptomonedas está vacío.')))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final asset = data.cryptoAssets[index];
                          final marketCoin = data.marketPrices[asset.coinId] ?? app_models.CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0);
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

  // --- NUEVO WIDGET AUXILIAR para construir el AppBar ---
  AppBar _buildAppBar(DashboardData? data) {
    return AppBar(
      title: const Text('Mi Portafolio Global'),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          tooltip: 'Análisis Fiat',
          onPressed: data == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => FiatAnalysisScreen(fiatHoldings: data.fiatHoldings, totalInvestedByFiat: data.summary.totalInvestedByFiat, totalRecoveredByFiat: data.summary.totalRecoveredByFiat))),
        ),
        IconButton(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          tooltip: 'Cuentas',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountsScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Configuración',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar Sesión',
          onPressed: () => FirebaseAuth.instance.signOut(),
        ),
      ],
    );
  }
}