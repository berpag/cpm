// lib/presentation/screens/dashboard/dashboard_screen.dart

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
  // ... (estado y métodos iniciales sin cambios)
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
      print("Error: $e");
      setState(() { _isLoading = false; });
    }
  }

  void _showAddCoinDialog() {
    final searchController = TextEditingController();
    final amountController = TextEditingController();
    final totalCostController = TextEditingController();
    CryptoCoin? selectedCoin;
    List<CryptoCoin> searchResults = [];
    PortfolioAsset? paymentAsset;
    bool isSearching = false;
    bool isFetchingPrice = false;
    CryptoCoin? paymentMarketCoin;
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
        paymentMarketCoin = _marketPrices.firstWhere((coin) => coin.id == paymentAsset!.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 1.0));
        priceOfPaymentCoin = paymentMarketCoin?.price ?? 1.0;
      }

      if (priceOfPaymentCoin == 0) return;
      final totalValueInUSD = amountReceived * priceOfReceivedCoin;
      final costInPaymentAsset = totalValueInUSD / priceOfPaymentCoin;
      totalCostController.text = costInPaymentAsset.toStringAsFixed(8);
    }
    
    amountController.addListener(calculateCost);

    showDialog(
      barrierDismissible: false, context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> performSearch(String query) async {
              if (query.isEmpty) { setDialogState(() => searchResults = []); return; }
              setDialogState(() => isSearching = true);
              try {
                final results = await ApiService.searchCoins(query);
                setDialogState(() => searchResults = results);
              } catch (e) { print("Error: $e"); } 
              finally { setDialogState(() => isSearching = false); }
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
              final DateTime? pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2009), lastDate: DateTime.now());
              if (pickedDate != null && context.mounted) {
                final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
                if (pickedTime != null) {
                  final newSelectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                  setDialogState(() { selectedDate = newSelectedDate; });
                  
                  if (selectedCoin != null && paymentAsset != null) {
                    setDialogState(() => isFetchingPrice = true);
                    try {
                      final prices = await Future.wait([
                        ApiService.getHistoricalPrice(selectedCoin!.id, selectedDate),
                        ApiService.getHistoricalPrice(paymentAsset!.coinId, selectedDate),
                      ]);
                      setDialogState(() {
                        historicalReceivedPrice = prices[0];
                        historicalPaymentPrice = prices[1];
                        calculateCost();
                      });
                    } catch (e) { print("Error: $e"); }
                    finally { setDialogState(() => isFetchingPrice = false); }
                  }
                }
              }
            }
            
            Widget transactionSummary() {
              if (selectedCoin == null || paymentAsset == null || amountController.text.isEmpty || totalCostController.text.isEmpty) { return const SizedBox.shrink(); }
              final totalValueInUSD = (double.tryParse(amountController.text) ?? 0) * (isHistoricalTransaction ? historicalReceivedPrice : selectedCoin!.price);
              final paymentPrice = isHistoricalTransaction ? historicalPaymentPrice : paymentMarketCoin?.price;

              return Container(
                margin: const EdgeInsets.only(top: 20), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen de la Transacción:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                    const Divider(),
                    Text('Precio de ${selectedCoin!.ticker}: \$${(isHistoricalTransaction ? historicalReceivedPrice : selectedCoin!.price).toStringAsFixed(2)}'),
                    Text('Precio de ${paymentAsset!.ticker}: \$${paymentPrice?.toStringAsFixed(2) ?? 'N/A'}'),
                    const SizedBox(height: 8),
                    Text('Valor Total: \$${totalValueInUSD.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: const Text('Registrar Intercambio (Swap)'),
              content: SingleChildScrollView(child: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                const Text('Moneda que Recibes:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: searchController, decoration: const InputDecoration(labelText: 'Buscar Moneda', suffixIcon: Icon(Icons.search)), onChanged: performSearch),
                if (isSearching) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                else if (searchResults.isNotEmpty) SizedBox(height: 150, child: ListView.builder(itemCount: searchResults.length, itemBuilder: (context, index) { final coin = searchResults[index]; return ListTile(title: Text(coin.name), subtitle: Text(coin.ticker), onTap: () => onCoinSelected(coin)); })),
                if (isFetchingPrice) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator()),
                TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Cantidad Recibida'), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                SwitchListTile(title: const Text('Transacción Histórica'), value: isHistoricalTransaction, onChanged: (bool value) { setDialogState(() { isHistoricalTransaction = value; calculateCost(); }); }),
                if (isHistoricalTransaction) ElevatedButton.icon(onPressed: selectDateTime, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('dd-MM-yyyy HH:mm').format(selectedDate))),
                const SizedBox(height: 10),
                const Text('Moneda que Entregas:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<PortfolioAsset>(
                  isExpanded: true, value: paymentAsset, hint: const Text('Seleccionar moneda de pago'),
                  items: _myPortfolio.map((PortfolioAsset asset) { return DropdownMenuItem<PortfolioAsset>(value: asset, child: Text('${asset.ticker} (Tienes: ${asset.amount})')); }).toList(),
                  onChanged: (PortfolioAsset? newValue) { setDialogState(() { paymentAsset = newValue; calculateCost(); }); },
                ),
                TextField(controller: totalCostController, decoration: const InputDecoration(labelText: 'Cantidad Entregada (Coste)'), keyboardType: TextInputType.number),
                transactionSummary(),
              ]))),
              actions: <Widget>[
                TextButton(child: const Text('Cancelar'), onPressed: () { amountController.removeListener(calculateCost); Navigator.of(context).pop(); }),
                ElevatedButton(child: const Text('Registrar'), onPressed: () {
                    final double receivedAmount = double.tryParse(amountController.text) ?? 0.0;
                    final double totalCost = double.tryParse(totalCostController.text) ?? 0.0;
                    if (selectedCoin != null && paymentAsset != null && receivedAmount > 0 && totalCost > 0 && paymentAsset!.amount >= totalCost) {
                      double purchasePriceInUSD;

                      // --- ¡LA CORRECCIÓN ESTÁ AQUÍ! ---
                      // Nos aseguramos de tener el precio de mercado de la moneda de pago.
                      final finalPaymentMarketCoin = _marketPrices.firstWhere(
                        (coin) => coin.id == paymentAsset!.coinId,
                        orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 1.0)
                      );
                      
                      if (isHistoricalTransaction) {
                        purchasePriceInUSD = (totalCost * historicalPaymentPrice) / receivedAmount;
                      } else {
                        purchasePriceInUSD = (totalCost * finalPaymentMarketCoin.price) / receivedAmount;
                      }

                      setState(() {
                        final paymentAssetIndex = _myPortfolio.indexOf(paymentAsset!);
                        _myPortfolio[paymentAssetIndex] = PortfolioAsset(
                          coinId: paymentAsset!.coinId, name: paymentAsset!.name, ticker: paymentAsset!.ticker,
                          amount: paymentAsset!.amount - totalCost, averageBuyPrice: paymentAsset!.averageBuyPrice,
                        );
                        final newAsset = PortfolioAsset(
                          coinId: selectedCoin!.id, name: selectedCoin!.name, ticker: selectedCoin!.ticker,
                          amount: receivedAmount, averageBuyPrice: purchasePriceInUSD,
                        );
                        _myPortfolio.add(newAsset);
                      });
                      amountController.removeListener(calculateCost);
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
      floatingActionButton: FloatingActionButton(onPressed: _showAddCoinDialog, backgroundColor: Colors.purple, foregroundColor: Colors.white, child: const Icon(Icons.add)),
    );
  }
}