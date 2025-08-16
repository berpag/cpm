// Versión 3.0 - Carga Sincronizada
// lib/presentation/screens/dashboard/dashboard_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/swap_dialog_widget.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/fiat_dialog_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<PortfolioAsset> _myPortfolio = [];
  List<CryptoCoin> _marketPrices = [];
  bool _isLoading = true;
  StreamSubscription? _transactionsSubscription;

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

  // --- ¡LÓGICA DE INICIALIZACIÓN CORREGIDA! ---
  Future<void> _initializeData() async {
    if (mounted) setState(() => _isLoading = true);
    
    // 1. Cargamos los precios del mercado y ESPERAMOS a que terminen.
    await _loadMarketData();
    
    // 2. SOLO DESPUÉS de tener los precios, empezamos a escuchar los cambios del portafolio.
    _listenToPortfolioChanges();
  }

  Future<void> _loadMarketData() async {
    try {
      print("[_loadMarketData] Iniciando carga de precios de mercado...");
      final marketData = await ApiService.getCoins();
      if (mounted) {
        setState(() {
          _marketPrices = marketData;
        });
      }
      print("[_loadMarketData] Carga de precios completada.");
    } catch (e) {
      print("Error al cargar datos del mercado: $e");
    }
  }
  
  // --- LÓGICA DE ESCUCHA MODIFICADA ---
  void _listenToPortfolioChanges() {
    _transactionsSubscription?.cancel();
    _transactionsSubscription = FirestoreService.getTransactionsStream().listen((transactions) {
      print("Nuevos datos de transacciones recibidos (${transactions.length}).");
      
      // La condición `if (_marketPrices.isNotEmpty)` ya no es necesaria aquí,
      // porque nos aseguramos de que los precios se carguen ANTES de llamar a esta función.
      final portfolio = PortfolioCalculator.calculate(transactions, _marketPrices);
      if (mounted) {
        setState(() {
          _myPortfolio = portfolio;
          // Dejamos de mostrar el loader solo cuando el primer cálculo se ha completado.
          if (_isLoading) {
            _isLoading = false;
          }
        });
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
          // Podríamos querer refrescar inmediatamente, pero el Stream lo hará por nosotros.
        },
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Portafolio (En Tiempo Real)'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _myPortfolio.isEmpty
            ? Center(
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
              )
            : RefreshIndicator(
                onRefresh: _initializeData,
                child: ListView.builder(
                  itemCount: _myPortfolio.length,
                  itemBuilder: (context, index) {
                    final asset = _myPortfolio[index];
                    final marketCoin = _marketPrices.firstWhere(
                      (coin) => coin.id.toLowerCase() == asset.coinId.toLowerCase(),
                      orElse: () => CryptoCoin(id: asset.coinId, name: asset.name, ticker: asset.ticker, price: 0.0),
                    );
                    return CryptoCoinCard(asset: asset, marketCoin: marketCoin);
                  },
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