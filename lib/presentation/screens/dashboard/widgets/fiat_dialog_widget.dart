// lib/presentation/screens/dashboard/widgets/fiat_dialog_widget.dart

import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';

class FiatDialog extends StatefulWidget {
  final List<CryptoCoin> marketPrices;
  final Function(Transaction) onTransactionAdded;

  const FiatDialog({
    super.key,
    required this.marketPrices,
    required this.onTransactionAdded,
  });

  @override
  State<FiatDialog> createState() => _FiatDialogState();
}

class _FiatDialogState extends State<FiatDialog> {
  final amountCryptoController = TextEditingController();
  final amountFiatController = TextEditingController();
  bool isBuy = true;
  CryptoCoin? selectedStablecoin;
  String selectedFiatCurrency = 'USD';
  final List<String> fiatCurrencies = ['USD', 'COP', 'EUR'];
  Map<String, double> fiatRates = {};
  bool areRatesLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDialog();
  }

  @override
  void dispose() {
    amountCryptoController.removeListener(_calculateFiatAmount);
    amountCryptoController.dispose();
    amountFiatController.dispose();
    super.dispose();
  }

  void _initializeDialog() async {
    final rates = await ApiService.getFiatExchangeRates();
    if (mounted) {
      setState(() {
        fiatRates = rates;
        areRatesLoading = false;
      });
    }
  }

  void _calculateFiatAmount() {
    if (selectedStablecoin != null && amountCryptoController.text.isNotEmpty) {
      final cryptoAmount = double.tryParse(amountCryptoController.text);
      if (cryptoAmount != null) {
        final valueInUSD = cryptoAmount * selectedStablecoin!.price;
        final exchangeRate = fiatRates[selectedFiatCurrency] ?? 1.0;
        final fiatAmount = valueInUSD * exchangeRate;
        amountFiatController.text = fiatAmount.toStringAsFixed(2);
      }
    }
  }

  void _onStablecoinSelected(CryptoCoin coin) {
    setState(() {
      selectedStablecoin = coin;
      _calculateFiatAmount();
    });
  }

  void _registerTransaction() {
    final cryptoAmount = double.tryParse(amountCryptoController.text);
    final fiatAmount = double.tryParse(amountFiatController.text);

    if (selectedStablecoin == null || cryptoAmount == null || fiatAmount == null || cryptoAmount <= 0 || fiatAmount <= 0) {
      print("Datos inválidos.");
      return;
    }
    
    final newTransaction = Transaction(
      type: isBuy ? 'buy' : 'sell',
      date: DateTime.now(),
      fiatCurrency: selectedFiatCurrency,
      fiatAmount: fiatAmount,
      cryptoCoinId: selectedStablecoin!.id,
      cryptoAmount: cryptoAmount,
    );

    FirestoreService.addTransaction(newTransaction)
      .then((_) => print("Transacción FIAT guardada en Firestore."))
      .catchError((error) => print("Error al guardar la transacción FIAT: $error"));
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isBuy ? 'Comprar Crypto con Fiat' : 'Vender Crypto por Fiat'),
      content: areRatesLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(isBuy ? 'Comprar' : 'Vender'),
                    value: isBuy,
                    onChanged: (value) => setState(() => isBuy = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Seleccionar Stablecoin'),
                    value: selectedStablecoin?.id,
                    items: widget.marketPrices
                        .where((c) => ['tether', 'usd-coin'].contains(c.id))
                        .map((CryptoCoin coin) {
                      return DropdownMenuItem<String>(
                        value: coin.id,
                        child: Text('${coin.name} (${coin.ticker})'),
                      );
                    }).toList(),
                    onChanged: (String? coinId) {
                      if (coinId != null) {
                        final coin = widget.marketPrices.firstWhere((c) => c.id == coinId);
                        _onStablecoinSelected(coin);
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
                        setState(() {
                          selectedFiatCurrency = newValue;
                          _calculateFiatAmount();
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: amountFiatController,
                    decoration: InputDecoration(labelText: 'Cantidad $selectedFiatCurrency (Automático)'),
                    keyboardType: TextInputType.number,
                    readOnly: true,
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
          onPressed: _registerTransaction,
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}