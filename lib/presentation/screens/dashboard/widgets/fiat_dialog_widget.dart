// lib/presentation/screens/dashboard/widgets/fiat_dialog_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart'; // ¡Lo necesitaremos!
import 'package:intl/intl.dart';

class FiatDialog extends StatefulWidget {
  // Ya no necesita recibir nada.
  const FiatDialog({ super.key });

  @override
  State<FiatDialog> createState() => _FiatDialogState();
}

class _FiatDialogState extends State<FiatDialog> {
  final cryptoSearchController = TextEditingController();
  final amountCryptoController = TextEditingController();
  
  bool isBuy = true;
  CryptoCoin? selectedCrypto;
  List<CryptoCoin> cryptoSearchResults = [];
  bool isCryptoSearching = false;
  Timer? _debounce;
  DateTime selectedDate = DateTime.now();

  @override
  void dispose() {
    _debounce?.cancel();
    cryptoSearchController.dispose();
    amountCryptoController.dispose();
    super.dispose();
  }
  
  void _onCryptoSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || query.isEmpty) {
        setState(() => cryptoSearchResults = []);
        return;
      }
      setState(() => isCryptoSearching = true);
      try {
        final results = await ApiService.searchCoins(query);
        if (mounted) setState(() => cryptoSearchResults = results);
      } catch (e) {
        print("Error buscando criptomonedas: $e");
      } finally {
        if (mounted) setState(() => isCryptoSearching = false);
      }
    });
  }

  void _onCryptoSelected(CryptoCoin coin) {
    setState(() {
      selectedCrypto = coin;
      cryptoSearchResults = [];
      cryptoSearchController.text = coin.name;
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
    final cryptoAmount = double.tryParse(amountCryptoController.text);
    if (selectedCrypto == null || cryptoAmount == null || cryptoAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos.')));
      return;
    }
    
    // El 'change' es positivo si es compra, negativo si es venta
    final change = isBuy ? cryptoAmount : -cryptoAmount;

    final newTransaction = Transaction(
      sourceAccount: 'Manual', // Las transacciones manuales tienen esta fuente
      wallet: 'Spot', // Asumimos que las transacciones manuales son en Spot
      date: selectedDate,
      type: isBuy ? 'Manual Buy' : 'Manual Sell',
      cryptoCoinId: selectedCrypto!.id,
      cryptoAmount: change,
    );

    try {
      // Necesitamos guardar la transacción manual en Firestore para que el stream la detecte
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
          children: [
            SwitchListTile(title: Text(isBuy ? 'Comprar' : 'Vender'), value: isBuy, onChanged: (value) => setState(() => isBuy = value)),
            TextField(controller: cryptoSearchController, decoration: const InputDecoration(labelText: 'Buscar Criptomoneda'), onChanged: _onCryptoSearchChanged),
            if (isCryptoSearching) const CircularProgressIndicator()
            else if (cryptoSearchResults.isNotEmpty) SizedBox(height: 150, child: ListView.builder(itemCount: cryptoSearchResults.length, itemBuilder: (context, index) {
              final coin = cryptoSearchResults[index];
              return ListTile(title: Text(coin.name), onTap: () => _onCryptoSelected(coin));
            })),
            TextField(controller: amountCryptoController, decoration: InputDecoration(labelText: 'Cantidad ${selectedCrypto?.ticker ?? ''}'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _selectDateTime,
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat('dd-MM-yyyy HH:mm').format(selectedDate)),
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