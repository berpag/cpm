// Versión 1.2

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
  void initState() {
    super.initState();
    _loadMarketData();
  }
  Future<void> _loadMarketData() async {
    print("[_loadMarketData] Iniciando carga de precios de mercado...");
    try {
      final marketData = await ApiService.getCoins();
      if (mounted) {
        setState(() {
          _marketPrices = marketData;
          _isLoading = false;
        });
      }
      print("[_loadMarketData] Carga de precios completada exitosamente.");
    } catch (e) {
      print("[_loadMarketData] ERROR: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddCoinDialog() {
    print("\n\n--- [DIALOG] Abriendo Diálogo de Intercambio ---");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AddCoinDialog(
          myPortfolio: _myPortfolio,
          marketPrices: _marketPrices,
          onTransactionAdded: (PortfolioAsset newAsset, PortfolioAsset paymentAsset, double cost) {
            print("[DIALOG] Diálogo cerrado con un nuevo activo: ${newAsset.name}");
            setState(() {
              final paymentAssetIndex = _myPortfolio.indexOf(paymentAsset);
              _myPortfolio[paymentAssetIndex] = PortfolioAsset(
                coinId: paymentAsset.coinId,
                name: paymentAsset.name,
                ticker: paymentAsset.ticker,
                amount: paymentAsset.amount - cost,
                averageBuyPrice: paymentAsset.averageBuyPrice,
              );
              _myPortfolio.add(newAsset);
            });
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

class AddCoinDialog extends StatefulWidget {
  final List<PortfolioAsset> myPortfolio;
  final List<CryptoCoin> marketPrices;
  final Function(PortfolioAsset, PortfolioAsset, double) onTransactionAdded;

  const AddCoinDialog({
    super.key,
    required this.myPortfolio,
    required this.marketPrices,
    required this.onTransactionAdded,
  });

  @override
  State<AddCoinDialog> createState() => _AddCoinDialogState();
}

class _AddCoinDialogState extends State<AddCoinDialog> {
  late TextEditingController _searchController;
  late TextEditingController _amountController;
  late TextEditingController _totalCostController;
  Timer? _debounce;
  
  CryptoCoin? _selectedCoin;
  List<CryptoCoin> _searchResults = [];
  PortfolioAsset? _paymentAsset;
  bool _isSearching = false;
  bool _isFetchingPrice = false;
  bool _isHistoricalTransaction = false;
  DateTime _selectedDate = DateTime.now();
  double _historicalReceivedPrice = 0.0;
  double _historicalPaymentPrice = 0.0;

  @override
  void initState() {
    super.initState();
    print("[AddCoinDialog] initState: Inicializando controladores.");
    _searchController = TextEditingController();
    _amountController = TextEditingController();
    _totalCostController = TextEditingController();
    _amountController.addListener(_calculateCost);
  }

  @override
  void dispose() {
    print("[AddCoinDialog] dispose: Limpiando todos los recursos.");
    _debounce?.cancel();
    _amountController.removeListener(_calculateCost);
    _searchController.dispose();
    _amountController.dispose();
    _totalCostController.dispose();
    super.dispose();
  }

  void _calculateCost() {
    if (!mounted) return;
    print("[_calculateCost] Iniciando cálculo.");
    if (_selectedCoin == null) { print("[_calculateCost] SALIDA: _selectedCoin es nulo."); return; }
    if (_paymentAsset == null) { print("[_calculateCost] SALIDA: _paymentAsset es nulo."); return; }
    if (_amountController.text.isEmpty) { print("[_calculateCost] SALIDA: La cantidad está vacía."); return; }
    
    final amountReceived = double.tryParse(_amountController.text);
    if (amountReceived == null) { print("[_calculateCost] SALIDA: Cantidad no es un número válido."); return; }

    double priceOfReceivedCoin = _isHistoricalTransaction ? _historicalReceivedPrice : _selectedCoin!.price;
    double priceOfPaymentCoin;

    if (_isHistoricalTransaction) {
      priceOfPaymentCoin = _historicalPaymentPrice;
    } else {
      final paymentMarketCoin = widget.marketPrices.firstWhere((coin) => coin.id == _paymentAsset!.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 1.0));
      priceOfPaymentCoin = paymentMarketCoin.price;
    }

    print("[_calculateCost] Precio Recibida: $priceOfReceivedCoin, Precio Pago: $priceOfPaymentCoin");

    if (priceOfPaymentCoin == 0) { print("[_calculateCost] SALIDA: Precio de pago es 0."); return; }
    
    final totalValueInUSD = amountReceived * priceOfReceivedCoin;
    final costInPaymentAsset = totalValueInUSD / priceOfPaymentCoin;

    print("[_calculateCost] Coste final calculado: $costInPaymentAsset");
    
    _totalCostController.text = costInPaymentAsset.toStringAsFixed(8);
    print("--- _calculateCost completado ---");
  }
  
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      try {
        final results = await ApiService.searchCoins(query);
        if (mounted) setState(() => _searchResults = results);
      } catch (e) {
        print("[_onSearchChanged] ERROR en búsqueda: $e");
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _onCoinSelected(CryptoCoin coin) async {
    if (!mounted) return;
    setState(() { _isFetchingPrice = true; _searchResults = []; _searchController.text = coin.name; });
    try {
      final coinDetails = await ApiService.getCoinDetails(coin.id);
      if (mounted) {
        setState(() {
          _selectedCoin = coinDetails;
          if (!_isHistoricalTransaction) _calculateCost();
        });
      }
    } catch (e) {
      print("[_onCoinSelected] ERROR al obtener detalles: $e");
    } finally {
      if (mounted) setState(() => _isFetchingPrice = false);
    }
  }
  
  Future<void> _selectDateTime() async {
    if (_selectedCoin == null || _paymentAsset == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona ambas monedas primero.')));
      return;
    }

    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2009), lastDate: DateTime.now());
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate));
      if (pickedTime != null && mounted) {
        final newSelectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        setState(() { _selectedDate = newSelectedDate; _isFetchingPrice = true; });
        try {
          final prices = await Future.wait([
            ApiService.getHistoricalPrice(_selectedCoin!.id, _selectedDate),
            ApiService.getHistoricalPrice(_paymentAsset!.coinId, _selectedDate),
          ]);
          if (mounted) {
            setState(() {
              _historicalReceivedPrice = prices[0];
              _historicalPaymentPrice = prices[1];
              _calculateCost();
            });
          }
        } catch (e) {
          print("Error histórico: $e");
        } finally {
          if (mounted) setState(() => _isFetchingPrice = false);
        }
      }
    }
  }

  void _registerTransaction() {
    print("[_registerTransaction] Botón Registrar presionado.");
    final receivedAmount = double.tryParse(_amountController.text);
    final totalCost = double.tryParse(_totalCostController.text);

    if (_selectedCoin != null && _paymentAsset != null && receivedAmount != null && totalCost != null && receivedAmount > 0 && totalCost > 0 && _paymentAsset!.amount >= totalCost) {
      double purchasePriceInUSD;
      if (_isHistoricalTransaction) {
        purchasePriceInUSD = (totalCost * _historicalPaymentPrice) / receivedAmount;
      } else {
        final paymentMarketCoin = widget.marketPrices.firstWhere((coin) => coin.id == _paymentAsset!.coinId);
        purchasePriceInUSD = (totalCost * paymentMarketCoin.price) / receivedAmount;
      }
      
      final newAsset = PortfolioAsset(
        coinId: _selectedCoin!.id,
        name: _selectedCoin!.name,
        ticker: _selectedCoin!.ticker,
        amount: receivedAmount,
        averageBuyPrice: purchasePriceInUSD,
      );
      print("[_registerTransaction] Transacción válida.");
      widget.onTransactionAdded(newAsset, _paymentAsset!, totalCost);
      Navigator.of(context).pop();
    } else {
      print("[_registerTransaction] Transacción inválida. Faltan datos o fondos insuficientes.");
    }
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
              TextField(controller: _searchController, decoration: const InputDecoration(labelText: 'Buscar Moneda', suffixIcon: Icon(Icons.search)), onChanged: _onSearchChanged),
              if (_isSearching) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
              else if (_searchResults.isNotEmpty) SizedBox(height: 150, child: ListView.builder(itemCount: _searchResults.length, itemBuilder: (context, index) { final coin = _searchResults[index]; return ListTile(title: Text(coin.name), subtitle: Text(coin.ticker), onTap: () => _onCoinSelected(coin)); })),
              if (_isFetchingPrice) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator()),
              TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'Cantidad Recibida'), keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              const Text('Moneda que Entregas:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<PortfolioAsset>(
                isExpanded: true, value: _paymentAsset, hint: const Text('Seleccionar moneda de pago'),
                items: widget.myPortfolio.map((PortfolioAsset asset) { return DropdownMenuItem<PortfolioAsset>(value: asset, child: Text('${asset.ticker} (Tienes: ${asset.amount})')); }).toList(),
                onChanged: (PortfolioAsset? newValue) => setState(() { _paymentAsset = newValue; _calculateCost(); }),
              ),
              TextField(controller: _totalCostController, decoration: const InputDecoration(labelText: 'Cantidad Entregada (Coste)'), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              SwitchListTile(title: const Text('Transacción Histórica'), value: _isHistoricalTransaction, onChanged: (bool value) { setState(() { _isHistoricalTransaction = value; _calculateCost(); }); }),
              if (_isHistoricalTransaction) ElevatedButton.icon(onPressed: _selectDateTime, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('dd-MM-yyyy HH:mm').format(_selectedDate))),
              _TransactionSummary(
                selectedCoin: _selectedCoin,
                paymentAsset: _paymentAsset,
                amountController: _amountController,
                totalCostController: _totalCostController,
                isHistoricalTransaction: _isHistoricalTransaction,
                historicalReceivedPrice: _historicalReceivedPrice,
                historicalPaymentPrice: _historicalPaymentPrice,
                marketPrices: widget.marketPrices,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(child: const Text('Registrar'), onPressed: _registerTransaction),
      ],
    );
  }
}


class _TransactionSummary extends StatelessWidget {
  final CryptoCoin? selectedCoin;
  final PortfolioAsset? paymentAsset;
  final TextEditingController amountController;
  final TextEditingController totalCostController;
  final bool isHistoricalTransaction;
  final double historicalReceivedPrice;
  final double historicalPaymentPrice;
  final List<CryptoCoin> marketPrices;

  const _TransactionSummary({
    required this.selectedCoin,
    required this.paymentAsset,
    required this.amountController,
    required this.totalCostController,
    required this.isHistoricalTransaction,
    required this.historicalReceivedPrice,
    required this.historicalPaymentPrice,
    required this.marketPrices,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCoin == null || paymentAsset == null || amountController.text.isEmpty || totalCostController.text.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final priceOfReceivedCoin = isHistoricalTransaction ? historicalReceivedPrice : selectedCoin!.price;
    final paymentMarketCoin = marketPrices.firstWhere((c) => c.id == paymentAsset!.coinId, orElse: () => CryptoCoin(id: '', name: '', ticker: '', price: 0.0));
    final priceOfPaymentCoin = isHistoricalTransaction ? historicalPaymentPrice : paymentMarketCoin.price;
    final totalValueInUSD = (double.tryParse(amountController.text) ?? 0) * priceOfReceivedCoin;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen de la Transacción:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
          const Divider(),
          Text('Precio de ${selectedCoin!.ticker}: \$${priceOfReceivedCoin.toStringAsFixed(2)}'),
          Text('Precio de ${paymentAsset!.ticker}: \$${priceOfPaymentCoin.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          Text('Valor Total: \$${totalValueInUSD.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}