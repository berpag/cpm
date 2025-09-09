// lib/presentation/screens/dashboard/widgets/fiat_dialog_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/services/exchange_rate_service.dart';
import 'package:intl/intl.dart';

class FiatDialog extends StatefulWidget {
  const FiatDialog({ super.key });
  @override
  State<FiatDialog> createState() => _FiatDialogState();
}

class _FiatDialogState extends State<FiatDialog> {
  final cryptoSearchController = TextEditingController();
  final amountCryptoController = TextEditingController();
  final fiatSearchController = TextEditingController();
  final amountFiatController = TextEditingController();
  final manualRateController = TextEditingController();

  bool isBuy = true;
  DateTime selectedDate = DateTime.now();
  CryptoCoin? selectedCrypto;
  List<CryptoCoin> cryptoSearchResults = [];
  bool isCryptoSearching = false;
  String? selectedFiat;
  List<Map<String, String>> fiatSearchResults = [];
  final List<Map<String, String>> _allFiats = [
    {'code': 'USD', 'name': 'Dólar Estadounidense'}, {'code': 'COP', 'name': 'Peso Colombiano'},
    {'code': 'EUR', 'name': 'Euro'}, {'code': 'ARS', 'name': 'Peso Argentino'},
    {'code': 'MXN', 'name': 'Peso Mexicano'}, {'code': 'BRL', 'name': 'Real Brasileño'},
  ];

  bool isCalculating = false;
  bool isFiatAmountManual = false;
  double? _lastCryptoPriceUSD;
  double? _lastExchangeRate;
  double? _lastUsdValue;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    manualRateController.addListener(_recalculateManualFiatAmount);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    manualRateController.removeListener(_recalculateManualFiatAmount);
    cryptoSearchController.dispose(); amountCryptoController.dispose();
    fiatSearchController.dispose(); amountFiatController.dispose();
    manualRateController.dispose();
    super.dispose();
  }
  
  void _debounceTrigger(VoidCallback action) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), action);
  }

  void _onCryptoSearchChanged(String query) {
    _debounceTrigger(() async {
      if (!mounted || query.isEmpty) { if (mounted) setState(() => cryptoSearchResults = []); return; }
      if (mounted) setState(() => isCryptoSearching = true);
      try {
        final results = await ApiService.searchCoins(query);
        if (mounted) setState(() => cryptoSearchResults = results);
      } catch (e) { print("Error buscando criptomonedas: $e"); } 
      finally { if (mounted) setState(() => isCryptoSearching = false); }
    });
  }

  void _onFiatSearchChanged(String query) {
    _debounceTrigger(() {
      if (!mounted) return;
      if (query.isEmpty) { setState(() => fiatSearchResults = []); return; }
      final results = _allFiats.where((fiat) => fiat['code']!.toLowerCase().contains(query.toLowerCase()) || fiat['name']!.toLowerCase().contains(query.toLowerCase())).toList();
      setState(() => fiatSearchResults = results);
    });
  }

  void _onCryptoSelected(CryptoCoin coin) {
    setState(() { selectedCrypto = coin; cryptoSearchResults = []; cryptoSearchController.text = coin.name; _resetCalculations(); });
  }

  void _onFiatSelected(Map<String, String> fiat) {
    setState(() { selectedFiat = fiat['code']; fiatSearchResults = []; fiatSearchController.text = fiat['name']!; _resetCalculations(); });
  }
  
  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2009), lastDate: DateTime.now());
    if (pickedDate == null || !mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
    if (pickedTime == null || !mounted) return;
    setState(() {
      selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
      _resetCalculations();
    });
  }

  void _resetToNow() {
    setState(() {
      selectedDate = DateTime.now();
      _resetCalculations();
    });
  }

  void _resetCalculations() {
    amountFiatController.clear();
    manualRateController.clear();
    setState(() { _lastCryptoPriceUSD = null; _lastExchangeRate = null; _lastUsdValue = null; isFiatAmountManual = false; });
  }

  Future<void> _calculateValue() async {
    final cryptoAmount = double.tryParse(amountCryptoController.text);
    if (cryptoAmount == null || cryptoAmount <= 0 || selectedCrypto == null || selectedFiat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona ambas monedas y la cantidad de cripto.'), backgroundColor: Colors.orange));
      return;
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    setState(() => isCalculating = true);
    await _fetchHistoricalCryptoPrice();
    if (!mounted || _lastCryptoPriceUSD == null) { _handleCalculationError('No se pudo obtener el precio de la cripto.'); return; }
    _lastUsdValue = cryptoAmount * _lastCryptoPriceUSD!;

    if(requestedDay.isBefore(today)) {
      setState(() { isFiatAmountManual = true; isCalculating = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Para fechas históricas, introduce la tasa de cambio del día.'), backgroundColor: Colors.blue));
      return;
    }

    final exchangeRate = await ExchangeRateService.getExchangeRate(date: selectedDate, fromCurrency: 'USD', toCurrency: selectedFiat!);
    if (!mounted) return;
    if (exchangeRate == null) { _handleCalculationError('No se pudo obtener la tasa. Introduce el valor manualmente.'); return; }
    
    _lastExchangeRate = exchangeRate;
    final calculatedFiatAmount = _lastUsdValue! * exchangeRate;
    setState(() {
      amountFiatController.text = calculatedFiatAmount.toStringAsFixed(2);
      isCalculating = false;
    });
  }
  
  Future<void> _fetchHistoricalCryptoPrice() async {
    if (selectedCrypto == null) return;
    final cryptoPrice = await ApiService.getHistoricalCoinPrice(coinId: selectedCrypto!.id, date: selectedDate);
    if (mounted) setState(() => _lastCryptoPriceUSD = cryptoPrice);
  }
  
  void _recalculateManualFiatAmount() {
    if (!isFiatAmountManual || _lastCryptoPriceUSD == null) return;
    final cryptoAmount = double.tryParse(amountCryptoController.text);
    final manualRate = double.tryParse(manualRateController.text);
    if (cryptoAmount != null && manualRate != null) {
      _lastUsdValue = cryptoAmount * _lastCryptoPriceUSD!;
      _lastExchangeRate = manualRate;
      final calculatedAmount = _lastUsdValue! * manualRate;
      setState(() => amountFiatController.text = calculatedAmount.toStringAsFixed(2));
    }
  }

  void _handleCalculationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orange));
    setState(() { isCalculating = false; isFiatAmountManual = true; });
  }

  void _launchGoogleSearch() async {
    final formattedDate = DateFormat('MMMM d, yyyy').format(selectedDate);
    final query = 'USD to ${selectedFiat ?? 'currency'} exchange rate on $formattedDate';
    final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(url)) { await launchUrl(url); }
  }

  Future<void> _registerTransaction() async {
    final cryptoAmount = double.tryParse(amountCryptoController.text);
    final fiatAmount = double.tryParse(amountFiatController.text);
    if (selectedCrypto == null || cryptoAmount == null || cryptoAmount <= 0 ||
        selectedFiat == null || fiatAmount == null || fiatAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos correctamente.')));
      return;
    }
    final change = isBuy ? cryptoAmount : -cryptoAmount;
    double? usdValueForTx;
    if (!isFiatAmountManual && _lastUsdValue != null) {
      usdValueForTx = _lastUsdValue;
    } else if (isFiatAmountManual && _lastExchangeRate != null && _lastExchangeRate! > 0) {
      usdValueForTx = fiatAmount / _lastExchangeRate!;
    }
    final newTransaction = Transaction(
      sourceAccount: 'Manual', wallet: 'Spot', date: selectedDate,
      type: isBuy ? 'Manual Buy' : 'Manual Sell',
      cryptoCoinId: selectedCrypto!.id, cryptoAmount: change,
      fiatCurrency: selectedFiat, fiatAmount: fiatAmount,
      exchangeRateUsed: _lastExchangeRate,
      usdValue: usdValueForTx,
    );
    try {
      await FirestoreService.addTransaction(newTransaction);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transacción registrada con éxito.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Transacción Manual'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(title: Text(isBuy ? 'Comprar' : 'Vender'), value: isBuy, onChanged: (value) => setState(() => isBuy = value)),
            
            TextField(controller: cryptoSearchController, decoration: const InputDecoration(labelText: 'Buscar Criptomoneda'), onChanged: _onCryptoSearchChanged),
            if (isCryptoSearching) const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()))
            else if (cryptoSearchResults.isNotEmpty) 
              SizedBox( height: 150, width: 300, child: ListView.builder(shrinkWrap: true, itemCount: cryptoSearchResults.length, itemBuilder: (context, index) => ListTile(title: Text(cryptoSearchResults[index].name), onTap: () => _onCryptoSelected(cryptoSearchResults[index])))),
            
            TextField(controller: amountCryptoController, decoration: InputDecoration(labelText: 'Cantidad ${selectedCrypto?.ticker ?? ''}'), keyboardType: TextInputType.number),
            
            const Divider(height: 24, thickness: 1),

            Text(isBuy ? 'Pagado Con:' : 'Recibido en:', style: Theme.of(context).textTheme.bodySmall),
            TextField(controller: fiatSearchController, decoration: const InputDecoration(labelText: 'Buscar Moneda Fiat'), onChanged: _onFiatSearchChanged),
            if (fiatSearchResults.isNotEmpty)
              SizedBox( height: 150, width: 300, child: ListView.builder(shrinkWrap: true, itemCount: fiatSearchResults.length, itemBuilder: (context, index) => ListTile(title: Text('${fiatSearchResults[index]['name']} (${fiatSearchResults[index]['code']})'), onTap: () => _onFiatSelected(fiatSearchResults[index])))),
            
            if (isFiatAmountManual)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextField(
                  controller: manualRateController,
                  decoration: InputDecoration(labelText: 'Tasa de Cambio (1 USD -> ${selectedFiat ?? ''})'),
                  keyboardType: TextInputType.number,
                ),
              ),

            TextField(
              controller: amountFiatController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Costo Total ${selectedFiat ?? ''}',
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (!isFiatAmountManual)
              isCalculating
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(onPressed: _calculateValue, icon: const Icon(Icons.calculate), label: const Text("Calcular Costo")),

            if (_lastCryptoPriceUSD != null && _lastExchangeRate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Detalles: 1 ${selectedCrypto?.ticker ?? ''} ≈ \$${_lastCryptoPriceUSD!.toStringAsFixed(2)}, Tasa: ${_lastExchangeRate!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),

            if (isFiatAmountManual)
              TextButton.icon(
                icon: const Icon(Icons.help_outline, size: 16, color: Colors.blue),
                label: const Text('¿No sabes la tasa? Búscala aquí', style: TextStyle(color: Colors.blue)),
                onPressed: selectedFiat == null ? null : _launchGoogleSearch,
              ),

            const SizedBox(height: 20),
            
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
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _registerTransaction, child: const Text('Registrar')),
      ],
    );
  }
}