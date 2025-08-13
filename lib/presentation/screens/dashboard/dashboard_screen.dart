// lib/presentation/screens/dashboard/dashboard_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/presentation/screens/dashboard/widgets/crypto_coin_card.dart';
import 'package:intl/intl.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // ... (El estado y los métodos iniciales no cambian)
  final List<PortfolioAsset> _myPortfolio = [
    PortfolioAsset(coinId: 'tether', name: 'Tether', ticker: 'USDT', amount: 1000.0, averageBuyPrice: 1.0),
    PortfolioAsset(coinId: 'bitcoin', name: 'Bitcoin', ticker: 'BTC', amount: 0.5, averageBuyPrice: 45000.0),
    PortfolioAsset(coinId: 'ethereum', name: 'Ethereum', ticker: 'ETH', amount: 2.0, averageBuyPrice: 2200.0),
  ];
  List<CryptoCoin> _marketPrices = [];
  bool _isLoading = true;
  @override
  void initState() { super.initState(); _loadMarketData(); }
  Future<void> _loadMarketData() async {
    try {
      final marketData = await ApiService.getCoins();
      setState(() { _marketPrices = marketData; _isLoading = false; });
    } catch (e) { print("Error: $e"); setState(() { _isLoading = false; }); }
  }

  void _showSwapDialog() {
    // ... (sin cambios)
  }

  void _showFiatDialog() {
    print("--- ABRIR DIÁLOGO FIAT ---");
    
    final amountCryptoController = TextEditingController();
    final amountFiatController = TextEditingController();
    bool isBuy = true;
    CryptoCoin? selectedStablecoin;
    String selectedFiatCurrency = 'USD';
    final List<String> fiatCurrencies = ['USD', 'COP', 'EUR'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            void onStablecoinSelected(CryptoCoin coin) {
              setDialogState(() => selectedStablecoin = coin);
            }

            return AlertDialog(
              title: Text(isBuy ? 'Comprar Crypto con Fiat' : 'Vender Crypto por Fiat'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: Text(isBuy ? 'Comprar' : 'Vender'),
                      value: isBuy,
                      onChanged: (value) => setDialogState(() => isBuy = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Seleccionar Stablecoin'),
                      value: selectedStablecoin?.id,
                      items: _marketPrices
                          .where((c) => ['tether', 'usd-coin'].contains(c.id))
                          .map((CryptoCoin coin) {
                            return DropdownMenuItem<String>(
                              value: coin.id,
                              child: Text('${coin.name} (${coin.ticker})'),
                            );
                          }).toList(),
                      onChanged: (String? coinId) {
                        final coin = _marketPrices.firstWhere((c) => c.id == coinId);
                        onStablecoinSelected(coin);
                      },
                    ),
                    TextField(
                      controller: amountCryptoController,
                      decoration: InputDecoration(labelText: 'Cantidad ${selectedStablecoin?.ticker ?? 'Crypto'}'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedFiatCurrency,
                      items: fiatCurrencies.map((String currency) {
                        return DropdownMenuItem<String>(
                          value: currency,
                          child: Text(currency),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() => selectedFiatCurrency = newValue!);
                      },
                    ),
                    TextField(
                      controller: amountFiatController,
                      decoration: InputDecoration(labelText: 'Cantidad $selectedFiatCurrency'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final cryptoAmount = double.tryParse(amountCryptoController.text);
                    final fiatAmount = double.tryParse(amountFiatController.text);

                    if (selectedStablecoin == null || cryptoAmount == null || fiatAmount == null || cryptoAmount <= 0 || fiatAmount <= 0) {
                      print("Datos inválidos.");
                      return;
                    }

                    setState(() {
                      final existingAssetIndex = _myPortfolio.indexWhere((a) => a.coinId == selectedStablecoin!.id);

                      if (isBuy) {
                        if (existingAssetIndex != -1) {
                          final existingAsset = _myPortfolio[existingAssetIndex];
                          final newAmount = existingAsset.amount! + cryptoAmount;
                          _myPortfolio[existingAssetIndex].amount = newAmount;
                        } else {
                          _myPortfolio.add(PortfolioAsset(
                            coinId: selectedStablecoin!.id,
                            name: selectedStablecoin!.name,
                            ticker: selectedStablecoin!.ticker,
                            amount: cryptoAmount,
                            averageBuyPrice: fiatAmount / cryptoAmount,
                          ));
                        }
                        print("Compra registrada: $cryptoAmount ${selectedStablecoin!.ticker}");
                      } else {
                        if (existingAssetIndex != -1) {
                          final existingAsset = _myPortfolio[existingAssetIndex];
                          if (existingAsset.amount! >= cryptoAmount) {
                            existingAsset.amount = existingAsset.amount! - cryptoAmount;
                            print("Venta registrada: $cryptoAmount ${selectedStablecoin!.ticker}");
                            if (existingAsset.amount == 0) {
                              _myPortfolio.removeAt(existingAssetIndex);
                              print("${existingAsset.ticker} eliminado del portafolio.");
                            }
                          } else {
                            print("Fondos insuficientes para vender.");
                          }
                        } else {
                          print("No se puede vender una moneda que no se posee.");
                        }
                      }
                    });
                    
                    Navigator.of(context).pop();
                  },
                  child: const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('Mi Portafolio (En Tiempo Real)'), backgroundColor: Colors.purple, foregroundColor: Colors.white),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView.builder(
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