// lib/presentation/screens/dashboard/widgets/swap_dialog_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/portfolio_calculator.dart';
import 'package:intl/intl.dart';

class SwapDialog extends StatefulWidget {
  final List<PortfolioAsset> myPortfolio;
  final List<CryptoCoin> marketPrices;

  const SwapDialog({
    super.key,
    required this.myPortfolio,
    required this.marketPrices,
  });

  @override
  State<SwapDialog> createState() => _SwapDialogState();
}

class _SwapDialogState extends State<SwapDialog> {
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
  
  @override
  void initState() {
    super.initState();
    amountController.addListener(_calculateCost);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    amountController.removeListener(_calculateCost);
    searchController.dispose();
    amountController.dispose();
    totalCostController.dispose();
    super.dispose();
  }

  void _calculateCost() {
    if (selectedCoin == null || paymentAsset == null || amountController.text.isEmpty) return;
    final amountReceived = double.tryParse(amountController.text);
    if (amountReceived == null) return;
    
    double priceOfReceivedCoin = isHistoricalTransaction ? historicalReceivedPrice : selectedCoin!.price;
    double priceOfPaymentCoin;

    if (isHistoricalTransaction) {
      priceOfPaymentCoin = historicalPaymentPrice;
    } else {
      final paymentMarketCoin = widget.marketPrices.firstWhere((coin) => coin.id == paymentAsset!.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 1.0));
      priceOfPaymentCoin = paymentMarketCoin.price;
    }

    if (priceOfPaymentCoin == 0) return;
    final totalValueInUSD = amountReceived * priceOfReceivedCoin;
    final costInPaymentAsset = totalValueInUSD / priceOfPaymentCoin;
    totalCostController.text = costInPaymentAsset.toStringAsFixed(8);
  }
  
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => isSearching = true);
      try {
        final results = await ApiService.searchCoins(query);
        if (mounted) setState(() => searchResults = results);
      } catch (e) { print("Error: $e"); } 
      finally { if (mounted) setState(() => isSearching = false); }
    });
  }
  
  Future<void> _onCoinSelected(CryptoCoin coin) async {
    if (!mounted) return;
    setState(() { isFetchingPrice = true; searchResults = []; searchController.text = coin.name; });
    try {
      final coinDetails = await ApiService.getCoinDetails(coin.id);
      if (mounted) {
        setState(() {
          selectedCoin = coinDetails;
          if (!isHistoricalTransaction) _calculateCost();
        });
      }
    } catch (e) { print("Error: $e"); } 
    finally { if (mounted) setState(() => isFetchingPrice = false); }
  }
  
  Future<void> _selectDateTime() async {
    if (selectedCoin == null || paymentAsset == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona ambas monedas primero.')));
      return;
    }
    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2009), lastDate: DateTime.now());
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
      if (pickedTime != null && mounted) {
        final newSelectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        setState(() { selectedDate = newSelectedDate; isFetchingPrice = true; });
        try {
          final prices = await Future.wait([
            ApiService.getHistoricalPrice(selectedCoin!.id, selectedDate),
            ApiService.getHistoricalPrice(paymentAsset!.coinId, selectedDate),
          ]);
          if (mounted) {
            setState(() {
              historicalReceivedPrice = prices[0];
              historicalPaymentPrice = prices[1];
              _calculateCost();
            });
          }
        } catch (e) { print("Error: $e"); }
        finally { if (mounted) setState(() => isFetchingPrice = false); }
      }
    }
  }

    void _registerTransaction() async {
    // Mostramos un loader para dar feedback
    if (!mounted) return;
    setState(() => isFetchingPrice = true);

    final double receivedAmount = double.tryParse(amountController.text) ?? 0.0;
    final double totalCost = double.tryParse(totalCostController.text) ?? 0.0;
    
    bool hasSufficientFunds = false;

    if (selectedCoin != null && paymentAsset != null && receivedAmount > 0 && totalCost > 0) {
      if (isHistoricalTransaction) {
        print("[VALIDATION] Iniciando validación histórica...");
        try {
          final allTransactions = await FirestoreService.getTransactions();
          final pastTransactions = allTransactions.where((tx) => tx.date.isBefore(selectedDate)).toList();
          final pastPortfolio = PortfolioCalculator.calculate(pastTransactions, widget.marketPrices);
          
          final pastAsset = pastPortfolio.firstWhere(
            (asset) => asset.coinId == paymentAsset!.coinId,
            orElse: () => PortfolioAsset(coinId: '', name: '', ticker: '', amount: 0, averageBuyPrice: 0, totalInvestedUSD: 0),
          );
          
          print("[VALIDATION] Fondos históricos de ${paymentAsset!.ticker}: ${pastAsset.amount}");
          print("[VALIDATION] Coste requerido: $totalCost");
          
          hasSufficientFunds = (pastAsset.amount ?? 0) >= totalCost;
        } catch (e) {
          print("Error durante la validación histórica: $e");
          hasSufficientFunds = false;
        }

      } else {
        hasSufficientFunds = paymentAsset!.amount! >= totalCost;
      }

      if (hasSufficientFunds) {
        print("[VALIDATION] Fondos suficientes. Guardando transacción.");
        final newTransaction = Transaction(
          type: 'swap',
          date: isHistoricalTransaction ? selectedDate : DateTime.now(),
          fromCoinId: paymentAsset!.coinId,
          fromAmount: totalCost,
          toCoinId: selectedCoin!.id,
          toAmount: receivedAmount,
        );
        try {
          await FirestoreService.addTransaction(newTransaction);
          print("Transacción de SWAP guardada en Firestore.");
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          print("Error al guardar la transacción de SWAP: $e");
        }
      } else {
        print("[VALIDATION] Fondos históricos insuficientes.");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fondos insuficientes de ${paymentAsset!.ticker} en la fecha seleccionada.'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      print("[VALIDATION] Datos del formulario inválidos.");
    }
    
    if (mounted) setState(() => isFetchingPrice = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Intercambio (Swap)'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(controller: searchController, decoration: const InputDecoration(labelText: 'Buscar Moneda', suffixIcon: Icon(Icons.search)), onChanged: _onSearchChanged),
              if (isSearching) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
              else if (searchResults.isNotEmpty) SizedBox(height: 150, child: ListView.builder(itemCount: searchResults.length, itemBuilder: (context, index) { final coin = searchResults[index]; return ListTile(title: Text(coin.name), subtitle: Text(coin.ticker), onTap: () => _onCoinSelected(coin)); })),
              if (isFetchingPrice) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator()),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Cantidad Recibida'), keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              DropdownButton<PortfolioAsset>(
                isExpanded: true, value: paymentAsset, hint: const Text('Moneda que Entregas'),
                items: widget.myPortfolio.map((PortfolioAsset asset) { return DropdownMenuItem<PortfolioAsset>(value: asset, child: Text('${asset.ticker} (Tienes: ${asset.amount!})')); }).toList(),
                onChanged: (PortfolioAsset? newValue) { setState(() { paymentAsset = newValue; _calculateCost(); }); },
              ),
              TextField(controller: totalCostController, decoration: const InputDecoration(labelText: 'Cantidad Entregada (Coste)'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              SwitchListTile(title: const Text('Transacción Histórica'), value: isHistoricalTransaction, onChanged: (bool value) { setState(() { isHistoricalTransaction = value; _calculateCost(); }); }),
              if (isHistoricalTransaction) ElevatedButton.icon(onPressed: _selectDateTime, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('dd-MM-yyyy HH:mm').format(selectedDate))),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(onPressed: _registerTransaction, child: const Text('Registrar')),
      ],
    );
  }
}