// Versión 1.5 - Corregido
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
    } catch (e) {
      print("Error al cargar datos del mercado: $e");
      setState(() { _isLoading = false; });
    }
  }

  void _showSwapDialog() {
    final searchController = TextEditingController();
    final amountController = TextEditingController();
    final totalCostController = TextEditingController();
    CryptoCoin? selectedCoin;
    List<CryptoCoin> searchResults = [];
    PortfolioAsset? paymentAsset;
    bool isSearching = false;
    bool isFetchingPrice = false;
    Timer? _debounce;
    bool isHistoricalTransaction = false;
    DateTime selectedDate = DateTime.now();
    double historicalReceivedPrice = 0.0;
    double historicalPaymentPrice = 0.0;

    void calculateCost() {
      if (selectedCoin == null || paymentAsset == null || amountController.text.isEmpty) return;
      final amountReceived = double.tryParse(amountController.text);
      if (amountReceived == null) return;
      
      double priceOfReceivedCoin = isHistoricalTransaction ? historicalReceivedPrice : selectedCoin!.price;
      double priceOfPaymentCoin;

      if (isHistoricalTransaction) {
        priceOfPaymentCoin = historicalPaymentPrice;
      } else {
        final paymentMarketCoin = _marketPrices.firstWhere((coin) => coin.id == paymentAsset!.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 1.0));
        priceOfPaymentCoin = paymentMarketCoin.price;
      }

      if (priceOfPaymentCoin == 0) return;
      final totalValueInUSD = amountReceived * priceOfReceivedCoin;
      final costInPaymentAsset = totalValueInUSD / priceOfPaymentCoin;
      totalCostController.text = costInPaymentAsset.toStringAsFixed(8);
    }
    
    amountController.addListener(calculateCost);

    void disposeDialog() {
      _debounce?.cancel();
      amountController.removeListener(calculateCost);
      searchController.dispose();
      amountController.dispose();
      totalCostController.dispose();
    }
    
    showDialog(
      barrierDismissible: false, context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> performSearch(String query) async {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () async {
                if (query.isEmpty) { if (context.mounted) setDialogState(() => searchResults = []); return; }
                if (context.mounted) setDialogState(() => isSearching = true);
                try {
                  final results = await ApiService.searchCoins(query);
                  if (context.mounted) setDialogState(() => searchResults = results);
                } catch (e) { print("Error: $e"); } 
                finally { if (context.mounted) setDialogState(() => isSearching = false); }
              });
            }
            
            Future<void> onCoinSelected(CryptoCoin coin) async {
              setDialogState(() { isFetchingPrice = true; searchResults = []; searchController.text = coin.name; });
              try {
                final coinDetails = await ApiService.getCoinDetails(coin.id);
                setDialogState(() { selectedCoin = coinDetails; if (!isHistoricalTransaction) calculateCost(); });
              } catch (e) { print("Error: $e"); } 
              finally { setDialogState(() => isFetchingPrice = false); }
            }

            Future<void> selectDateTime() async {
              if (selectedCoin == null || paymentAsset == null) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona ambas monedas primero.')));
                return;
              }
              final DateTime? pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2009), lastDate: DateTime.now());
              if (pickedDate != null && context.mounted) {
                final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
                if (pickedTime != null) {
                  final newSelectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                  setDialogState(() { selectedDate = newSelectedDate; isFetchingPrice = true; });
                  try {
                    final prices = await Future.wait([
                      ApiService.getHistoricalPrice(selectedCoin!.id, selectedDate),
                      ApiService.getHistoricalPrice(paymentAsset!.coinId, selectedDate),
                    ]);
                    setDialogState(() { historicalReceivedPrice = prices[0]; historicalPaymentPrice = prices[1]; calculateCost(); });
                  } catch (e) { print("Error: $e"); }
                  finally { setDialogState(() => isFetchingPrice = false); }
                }
              }
            }
            
            Widget transactionSummary() {
              if (selectedCoin == null || paymentAsset == null || amountController.text.isEmpty || totalCostController.text.isEmpty) { return const SizedBox.shrink(); }
              final paymentMarketCoin = _marketPrices.firstWhere((c) => c.id == paymentAsset!.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0.0));
              final totalValueInUSD = (double.tryParse(amountController.text) ?? 0) * (isHistoricalTransaction ? historicalReceivedPrice : selectedCoin!.price);
              final paymentPrice = isHistoricalTransaction ? historicalPaymentPrice : paymentMarketCoin.price;

              return Container(
                margin: const EdgeInsets.only(top: 20), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen de la Transacción:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                    const Divider(),
                    Text('Precio de ${selectedCoin!.ticker}: \$${(isHistoricalTransaction ? historicalReceivedPrice : selectedCoin!.price).toStringAsFixed(2)}'),
                    Text('Precio de ${paymentAsset!.ticker}: \$${paymentPrice.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    Text('Valor Total: \$${totalValueInUSD.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: const Text('Registrar Intercambio (Swap)'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Moneda que Recibes:', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextField(controller: searchController, decoration: const InputDecoration(labelText: 'Buscar Moneda', suffixIcon: Icon(Icons.search)), onChanged: performSearch),
                      if (isSearching) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                      else if (searchResults.isNotEmpty) SizedBox(height: 150, child: ListView.builder(itemCount: searchResults.length, itemBuilder: (context, index) { final coin = searchResults[index]; return ListTile(title: Text(coin.name), subtitle: Text(coin.ticker), onTap: () => onCoinSelected(coin)); })),
                      if (isFetchingPrice) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator()),
                      TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Cantidad Recibida'), keyboardType: TextInputType.number),
                      const SizedBox(height: 20),
                      const Text('Moneda que Entregas:', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<PortfolioAsset>(
                        isExpanded: true, value: paymentAsset, hint: const Text('Seleccionar moneda de pago'),
                        items: _myPortfolio.map((PortfolioAsset asset) { return DropdownMenuItem<PortfolioAsset>(value: asset, child: Text('${asset.ticker} (Tienes: ${asset.amount})')); }).toList(),
                        onChanged: (PortfolioAsset? newValue) { setDialogState(() { paymentAsset = newValue; calculateCost(); }); },
                      ),
                      TextField(controller: totalCostController, decoration: const InputDecoration(labelText: 'Cantidad Entregada (Coste)'), keyboardType: TextInputType.number),
                      const SizedBox(height: 10),
                      SwitchListTile(title: const Text('Transacción Histórica'), value: isHistoricalTransaction, onChanged: (bool value) { setDialogState(() { isHistoricalTransaction = value; calculateCost(); }); }),
                      if (isHistoricalTransaction) ElevatedButton.icon(onPressed: selectDateTime, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('dd-MM-yyyy HH:mm').format(selectedDate))),
                      transactionSummary(),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(child: const Text('Cancelar'), onPressed: () { disposeDialog(); Navigator.of(context).pop(); }),
                ElevatedButton(child: const Text('Registrar'), onPressed: () {
                    final double receivedAmount = double.tryParse(amountController.text) ?? 0.0;
                    final double totalCost = double.tryParse(totalCostController.text) ?? 0.0;
                    if (selectedCoin != null && paymentAsset != null && receivedAmount > 0 && totalCost > 0 && paymentAsset!.amount! >= totalCost) {
                      double purchasePriceInUSD;
                      if (isHistoricalTransaction) {
                        purchasePriceInUSD = (totalCost * historicalPaymentPrice) / receivedAmount;
                      } else {
                        final paymentMarketCoin = _marketPrices.firstWhere((coin) => coin.id == paymentAsset!.coinId);
                        purchasePriceInUSD = (totalCost * paymentMarketCoin.price) / receivedAmount;
                      }
                      setState(() {
                        final paymentAssetIndex = _myPortfolio.indexOf(paymentAsset!);
                        _myPortfolio[paymentAssetIndex].amount = _myPortfolio[paymentAssetIndex].amount! - totalCost;
                        
                        final newAsset = PortfolioAsset(
                          coinId: selectedCoin!.id, name: selectedCoin!.name, ticker: selectedCoin!.ticker,
                          amount: receivedAmount, averageBuyPrice: purchasePriceInUSD,
                        );
                        _myPortfolio.add(newAsset);
                      });
                      disposeDialog();
                      Navigator.of(context).pop();
                    }
                }),
              ],
            );
          },
        );
      },
    );
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
                        if (coinId != null) {
                          final coin = _marketPrices.firstWhere((c) => c.id == coinId);
                          onStablecoinSelected(coin);
                        }
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
                        if (newValue != null) {
                          setDialogState(() => selectedFiatCurrency = newValue);
                        }
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
                          existingAsset.amount = (existingAsset.amount ?? 0) + cryptoAmount;
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
                          if ((existingAsset.amount ?? 0) >= cryptoAmount) {
                            existingAsset.amount = (existingAsset.amount ?? 0) - cryptoAmount;
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