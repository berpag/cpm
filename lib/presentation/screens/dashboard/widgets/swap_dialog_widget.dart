// lib/presentation/screens/dashboard/widgets/swap_dialog_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:intl/intl.dart';

class SwapDialog extends StatefulWidget {
  final List<PortfolioAsset> myPortfolio;

  const SwapDialog({
    super.key,
    required this.myPortfolio,
  });

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
  Timer? _debounce;
  DateTime selectedDate = DateTime.now();
  
  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    amountReceivedController.dispose();
    amountSentController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || query.isEmpty) {
        setState(() => searchResults = []);
        return;
      }
      setState(() => isSearching = true);
      try {
        final results = await ApiService.searchCoins(query);
        if (mounted) setState(() => searchResults = results);
      } catch (e) { print("Error buscando monedas: $e"); } 
      finally { if (mounted) setState(() => isSearching = false); }
    });
  }
  
  void _onCoinSelected(CryptoCoin coin) {
    setState(() {
      receivedCoin = coin;
      searchResults = [];
      searchController.text = coin.name;
    });
  }
  
  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2009), lastDate: DateTime.now());
    if (pickedDate == null || !mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
    if (pickedTime == null || !mounted) return;
    setState(() {
      selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    });
  }

  Future<void> _registerTransaction() async {
    final receivedAmount = double.tryParse(amountReceivedController.text);
    final sentAmount = double.tryParse(amountSentController.text);

    if (receivedCoin == null || sentAsset == null || receivedAmount == null || sentAmount == null || receivedAmount <= 0 || sentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos.')));
      return;
    }
    
    // Un swap son dos transacciones: una de salida y una de entrada
    final transactionOut = Transaction(
      sourceAccount: 'Manual',
      wallet: 'Spot', // Asumimos que los swaps manuales son en Spot
      date: selectedDate,
      type: 'Manual Swap (Out)',
      cryptoCoinId: sentAsset!.coinId,
      cryptoAmount: -sentAmount, // Negativo porque sale
    );

    final transactionIn = Transaction(
      sourceAccount: 'Manual',
      wallet: 'Spot',
      date: selectedDate,
      type: 'Manual Swap (In)',
      cryptoCoinId: receivedCoin!.id,
      cryptoAmount: receivedAmount, // Positivo porque entra
    );

    try {
      // Guardamos ambas transacciones en la base de datos
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
    return AlertDialog(
      title: const Text('Registrar Intercambio (Swap)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // --- Moneda que Entregas ---
            DropdownButton<PortfolioAsset>(
              isExpanded: true,
              value: sentAsset,
              hint: const Text('Moneda que Entregas'),
              items: widget.myPortfolio.map((asset) {
                // Usamos el totalAmount del nuevo modelo
                return DropdownMenuItem<PortfolioAsset>(value: asset, child: Text('${asset.ticker} (Tienes: ${asset.totalAmount})'));
              }).toList(),
              onChanged: (PortfolioAsset? newValue) {
                setState(() => sentAsset = newValue);
              },
            ),
            TextField(controller: amountSentController, decoration: InputDecoration(labelText: 'Cantidad Entregada'), keyboardType: TextInputType.number),
            
            const Divider(height: 30),

            // --- Moneda que Recibes ---
            TextField(controller: searchController, decoration: const InputDecoration(labelText: 'Buscar Moneda que Recibes'), onChanged: _onSearchChanged),
            if (isSearching) const CircularProgressIndicator()
            else if (searchResults.isNotEmpty) SizedBox(height: 150, child: ListView.builder(itemCount: searchResults.length, itemBuilder: (context, index) {
              final coin = searchResults[index];
              return ListTile(title: Text(coin.name), onTap: () => _onCoinSelected(coin));
            })),
            TextField(controller: amountReceivedController, decoration: InputDecoration(labelText: 'Cantidad Recibida'), keyboardType: TextInputType.number),
            
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _selectDateTime,
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat('dd-MM-yyyy HH:mm').format(selectedDate)),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop()),
        ElevatedButton(onPressed: _registerTransaction, child: const Text('Registrar')),
      ],
    );
  }
}