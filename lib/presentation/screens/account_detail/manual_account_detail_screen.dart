// lib/presentation/screens/account_detail/manual_account_detail_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart' as app_models;
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/fiat_dialog_widget.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/swap_dialog_widget.dart';

class ManualAccountDetailScreen extends StatefulWidget {
  // --- ¡CAMBIO! RECIBE LOS PRECIOS ---
  final List<app_models.CryptoCoin> marketPrices;

  const ManualAccountDetailScreen({
    super.key,
    required this.marketPrices,
  });

  @override
  State<ManualAccountDetailScreen> createState() => _ManualAccountDetailScreenState();
}

class _ManualAccountDetailScreenState extends State<ManualAccountDetailScreen> {
  StreamSubscription? _transactionsSubscription;
  List<app_models.PortfolioAsset> _manualAssets = [];
  List<app_models.PortfolioAsset> _fullPortfolioForDialog = [];
  
  // La variable _marketPrices se elimina del estado, ya que ahora la recibimos.

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
  
  // --- ¡LÓGICA SIMPLIFICADA! ---
  Future<void> _listenToPortfolioChanges() async {
    // Ya no necesitamos _isLoading, el StreamBuilder manejará los estados de carga.
    _transactionsSubscription?.cancel();
    _transactionsSubscription = FirestoreService.getTransactionsStream().listen((allTransactions) {
      if (!mounted) return;
      
      // Usamos la lista de precios que recibimos del widget.
      final manualPortfolio = PortfolioCalculator.calculate(allTransactions, widget.marketPrices, sourceAccount: 'Manual');
      final fullPortfolio = PortfolioCalculator.calculate(allTransactions, widget.marketPrices);

      setState(() {
        _manualAssets = manualPortfolio;
        _fullPortfolioForDialog = fullPortfolio;
      });
    });
  }

  void _showFiatDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const FiatDialog());
  }

  void _showSwapDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => SwapDialog(myPortfolio: _fullPortfolioForDialog));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Entradas Manuales'),
      ),
      // --- USAMOS STREAMBUILDER PARA MAYOR EFICIENCIA ---
      body: StreamBuilder<List<app_models.Transaction>>(
        stream: FirestoreService.getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Calculamos los activos aquí, dentro del builder
          final allTransactions = snapshot.data ?? [];
          final manualAssets = PortfolioCalculator.calculate(allTransactions, widget.marketPrices, sourceAccount: 'Manual');

          return RefreshIndicator(
            // El onRefresh ahora puede ser más simple.
            onRefresh: () async {
              // En un futuro, aquí podríamos forzar una actualización de precios desde el dashboard.
              // Por ahora, simplemente reconstruirá con los datos actuales.
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Wrap(
                      spacing: 16, runSpacing: 8, alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(onPressed: _showFiatDialog, icon: const Icon(Icons.attach_money), label: const Text('Registrar Compra/Venta')),
                        ElevatedButton.icon(onPressed: _showSwapDialog, icon: const Icon(Icons.swap_horiz), label: const Text('Registrar Swap')),
                      ],
                    ),
                  ),
                ),
                
                if (manualAssets.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No hay activos manuales.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final asset = manualAssets[index];
                        final marketCoin = widget.marketPrices.firstWhere(
                          (coin) => coin.id == asset.coinId,
                          orElse: () => app_models.CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0),
                        );
                        return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
                      },
                      childCount: manualAssets.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}