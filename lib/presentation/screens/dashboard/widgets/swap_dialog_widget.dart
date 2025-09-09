// lib/presentation/screens/dashboard/widgets/swap_dialog_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:intl/intl.dart';

enum SwapField { sent, received, none }

class SwapDialog extends StatefulWidget {
  final List<PortfolioAsset> myPortfolio;
  const SwapDialog({super.key, required this.myPortfolio});
  @override
  State<SwapDialog> createState() => _SwapDialogState();
}

class _SwapDialogState extends State<SwapDialog> {
  final searchController = TextEditingController();
  final amountReceivedController = TextEditingController();
  final amountSentController = TextEditingController();
  
  CryptoCoin? receivedCoin;
  PortfolioAsset? sentAsset;
  List<CryptoCoin> searchResults = [];
  bool isSearching = false;
  DateTime selectedDate = DateTime.now();
  
  bool isCalculating = false;
  double? _sentCoinPriceUSD;
  double? _receivedCoinPriceUSD;
  String? _errorMessage;
  Timer? _debounce;
  bool _isAutoFilling = false;
  SwapField _lastFocused = SwapField.none;

  @override
  void initState() {
    super.initState();
    amountSentController.addListener(_onSentAmountChanged);
    amountReceivedController.addListener(_onReceivedAmountChanged);
  }

  void _onSentAmountChanged() {
    if (_isAutoFilling) return;
    if (amountSentController.text.isNotEmpty) {
      if (amountReceivedController.text.isNotEmpty) {
        _isAutoFilling = true;
        amountReceivedController.clear();
        _isAutoFilling = false;
      }
      setState(() => _lastFocused = SwapField.sent);
    } else if (_lastFocused == SwapField.sent) {
      setState(() => _lastFocused = SwapField.none);
    }
    _validateBalance();
  }

  void _onReceivedAmountChanged() {
    if (_isAutoFilling) return;
    if (amountReceivedController.text.isNotEmpty) {
      if (amountSentController.text.isNotEmpty) {
        _isAutoFilling = true;
        amountSentController.clear();
        _isAutoFilling = false;
      }
      setState(() => _lastFocused = SwapField.received);
    } else if (_lastFocused == SwapField.received) {
      setState(() => _lastFocused = SwapField.none);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    amountSentController.removeListener(_onSentAmountChanged);
    amountReceivedController.removeListener(_onReceivedAmountChanged);
    searchController.dispose(); 
    amountReceivedController.dispose(); 
    amountSentController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || query.isEmpty) {
        if (mounted) setState(() => searchResults = []);
        return;
      }
      if (mounted) setState(() => isSearching = true);
      try {
        final results = await ApiService.searchCoins(query);
        if (mounted) setState(() => searchResults = results);
      } catch (e) {
        print("Error buscando monedas: $e");
      } finally {
        if (mounted) setState(() => isSearching = false);
      }
    });
  }
  
  void _onCoinSelected(CryptoCoin coin) { 
    setState(() { 
      receivedCoin = coin; 
      searchResults = []; 
      searchController.text = coin.name; 
      _resetCalculations(keepFocus: true);
    });
  }

  void onSentAssetChanged(PortfolioAsset? newValue) {
    setState(() { 
      sentAsset = newValue; 
      _resetCalculations(keepFocus: true);
      _validateBalance();
    });
  }
  
  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2009), lastDate: DateTime.now());
    if (pickedDate == null || !mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
    if (pickedTime == null || !mounted) return;
    setState(() {
      selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
      _resetCalculations(keepFocus: true);
    });
  }

  void _resetToNow() {
    setState(() {
      selectedDate = DateTime.now();
      _resetCalculations();
    });
  }

  void _resetCalculations({bool keepFocus = false}) {
    _isAutoFilling = true;
    
    if (!(keepFocus && _lastFocused == SwapField.sent)) {
      amountSentController.clear();
    }
    if (!(keepFocus && _lastFocused == SwapField.received)) {
      amountReceivedController.clear();
    }

    if (!keepFocus) {
      _lastFocused = SwapField.none;
    }
    
    Future.microtask(() => _isAutoFilling = false);

    setState(() {
      _sentCoinPriceUSD = null;
      _receivedCoinPriceUSD = null;
      _errorMessage = null;
    });
  }

  Future<void> _calculateSwap() async {
    final sentAmount = double.tryParse(amountSentController.text);
    final receivedAmount = double.tryParse(amountReceivedController.text);

    if (sentAsset == null || receivedCoin == null || _lastFocused == SwapField.none) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona ambas monedas e introduce una cantidad.'), backgroundColor: Colors.orange));
      return;
    }
    
    setState(() { isCalculating = true; _errorMessage = null; });
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    
    if (requestedDay.isBefore(today)) {
      final prices = await Future.wait([
        ApiService.getHistoricalCoinPrice(coinId: sentAsset!.coinId, date: selectedDate),
        ApiService.getHistoricalCoinPrice(coinId: receivedCoin!.id, date: selectedDate),
      ]);
      _sentCoinPriceUSD = prices[0];
      _receivedCoinPriceUSD = prices[1];
    } else {
      final marketData = await ApiService.getMarketDataForIds([sentAsset!.coinId, receivedCoin!.id]);
      _sentCoinPriceUSD = marketData.firstWhere((c) => c.id == sentAsset!.coinId, orElse: () => CryptoCoin(price: 0.0, id: '', name: '', ticker: '')).price;
      _receivedCoinPriceUSD = marketData.firstWhere((c) => c.id == receivedCoin!.id, orElse: () => CryptoCoin(price: 0.0, id: '', name: '', ticker: '')).price;
    }

    if (!mounted) return;

    if (_sentCoinPriceUSD == null || _receivedCoinPriceUSD == null || _receivedCoinPriceUSD == 0 || _sentCoinPriceUSD == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo obtener el precio de una o ambas monedas.'), backgroundColor: Colors.red));
      setState(() => isCalculating = false);
      return;
    }
    
    _isAutoFilling = true;
    if (_lastFocused == SwapField.sent && sentAmount != null) {
      final totalUsdValue = sentAmount * _sentCoinPriceUSD!;
      final calculatedAmount = totalUsdValue / _receivedCoinPriceUSD!;
      amountReceivedController.text = calculatedAmount.toStringAsFixed(8);
    } else if (_lastFocused == SwapField.received && receivedAmount != null) {
      final totalUsdValue = receivedAmount * _receivedCoinPriceUSD!;
      final calculatedAmount = totalUsdValue / _sentCoinPriceUSD!;
      amountSentController.text = calculatedAmount.toStringAsFixed(8);
    }
    
    Future.delayed(const Duration(milliseconds: 50), () => _isAutoFilling = false);
    
    setState(() => isCalculating = false);
    _validateBalance();
  }

  void _validateBalance() {
    final sentAmount = double.tryParse(amountSentController.text);
    if (sentAsset != null && sentAmount != null) {
      if (sentAmount > sentAsset!.totalAmount) {
        setState(() => _errorMessage = 'Saldo insuficiente. Tienes ${sentAsset!.totalAmount.toStringAsFixed(4)} ${sentAsset!.ticker}.');
      } else {
        setState(() => _errorMessage = null);
      }
    } else {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _registerTransaction() async {
    _validateBalance();
    if (_errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red));
      return;
    }
    final receivedAmount = double.tryParse(amountReceivedController.text);
    final sentAmount = double.tryParse(amountSentController.text);
    if (receivedCoin == null || sentAsset == null || receivedAmount == null || sentAmount == null || receivedAmount <= 0 || sentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos.')));
      return;
    }
    final transactionOut = Transaction(sourceAccount: 'Manual', wallet: 'Spot', date: selectedDate, type: 'Manual Swap (Out)', cryptoCoinId: sentAsset!.coinId, cryptoAmount: -sentAmount);
    final transactionIn = Transaction(sourceAccount: 'Manual', wallet: 'Spot', date: selectedDate, type: 'Manual Swap (In)', cryptoCoinId: receivedCoin!.id, cryptoAmount: receivedAmount);
    try {
      await FirestoreService.addTransactionsInBatch([transactionOut, transactionIn]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Swap registrado con éxito.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canRegister = _errorMessage == null;

    return AlertDialog(
      title: const Text('Registrar Intercambio (Swap)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButton<PortfolioAsset>(
              isExpanded: true, value: sentAsset, hint: const Text('Moneda que Entregas'),
              items: widget.myPortfolio.map((asset) => DropdownMenuItem<PortfolioAsset>(value: asset, child: Text('${asset.ticker} (Tienes: ${asset.totalAmount.toStringAsFixed(4)})'))).toList(),
              onChanged: onSentAssetChanged,
            ),
            TextField(controller: amountSentController, decoration: const InputDecoration(labelText: 'Cantidad Entregada'), keyboardType: TextInputType.number),
            
            const Divider(height: 24),

            TextField(controller: searchController, decoration: const InputDecoration(labelText: 'Buscar Moneda que Recibes'), onChanged: _onSearchChanged),
            if (isSearching) const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()))
            else if (searchResults.isNotEmpty) 
              SizedBox(height: 150, width: 300, child: ListView.builder(shrinkWrap: true, itemCount: searchResults.length, itemBuilder: (context, index) => ListTile(title: Text(searchResults[index].name), onTap: () => _onCoinSelected(searchResults[index])))),
            
            TextField(controller: amountReceivedController, decoration: const InputDecoration(labelText: 'Cantidad Recibida'), keyboardType: TextInputType.number),
            
            const SizedBox(height: 16),

            if (isCalculating)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                onPressed: _calculateSwap,
                icon: const Icon(Icons.calculate),
                label: const Text("Calcular Intercambio"),
              ),

            if (!isCalculating && _sentCoinPriceUSD != null && _receivedCoinPriceUSD != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Precios: 1 ${sentAsset?.ticker ?? ''} ≈ \$${_sentCoinPriceUSD!.toStringAsFixed(2)}, 1 ${receivedCoin?.ticker ?? ''} ≈ \$${_receivedCoinPriceUSD!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),
            
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
              ),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectDateTime,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('dd-MM-yy HH:mm').format(selectedDate)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _resetToNow,
                  child: const Text('Hoy'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(
          onPressed: canRegister ? _registerTransaction : null, 
          child: const Text('Registrar')
        ),
      ],
    );
  }
}