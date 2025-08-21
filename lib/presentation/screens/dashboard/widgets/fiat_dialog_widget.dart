// lib/presentation/screens/dashboard/widgets/fiat_dialog_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class FiatCurrency {
  final String code;
  final String name;
  final String symbol;

  FiatCurrency({required this.code, required this.name, required this.symbol});
}

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
  final List<FiatCurrency> _supportedFiats = [
    FiatCurrency(code: 'usd', name: 'Dólar Estadounidense', symbol: '\$'),
    FiatCurrency(code: 'eur', name: 'Euro', symbol: '€'),
    FiatCurrency(code: 'jpy', name: 'Yen Japonés', symbol: '¥'),
    FiatCurrency(code: 'gbp', name: 'Libra Esterlina', symbol: '£'),
    FiatCurrency(code: 'aud', name: 'Dólar Australiano', symbol: 'A\$'),
    FiatCurrency(code: 'cad', name: 'Dólar Canadiense', symbol: 'C\$'),
    FiatCurrency(code: 'chf', name: 'Franco Suizo', symbol: 'CHF'),
    FiatCurrency(code: 'cny', name: 'Yuan Chino', symbol: '¥'),
    FiatCurrency(code: 'hkd', name: 'Dólar de Hong Kong', symbol: 'HK\$'),
    FiatCurrency(code: 'nzd', name: 'Dólar Neozelandés', symbol: 'NZ\$'),
    FiatCurrency(code: 'sek', name: 'Corona Sueca', symbol: 'kr'),
    FiatCurrency(code: 'krw', name: 'Won Surcoreano', symbol: '₩'),
    FiatCurrency(code: 'sgd', name: 'Dólar de Singapur', symbol: 'S\$'),
    FiatCurrency(code: 'nok', name: 'Corona Noruega', symbol: 'kr'),
    FiatCurrency(code: 'mxn', name: 'Peso Mexicano', symbol: 'Mex\$'),
    FiatCurrency(code: 'inr', name: 'Rupia India', symbol: '₹'),
    FiatCurrency(code: 'rub', name: 'Rublo Ruso', symbol: '₽'),
    FiatCurrency(code: 'zar', name: 'Rand Sudafricano', symbol: 'R'),
    FiatCurrency(code: 'brl', name: 'Real Brasileño', symbol: 'R\$'),
    FiatCurrency(code: 'ars', name: 'Peso Argentino', symbol: '\$'),
    FiatCurrency(code: 'clp', name: 'Peso Chileno', symbol: '\$'),
    FiatCurrency(code: 'cop', name: 'Peso Colombiano', symbol: '\$'),
  ];

  final cryptoSearchController = TextEditingController();
  final fiatSearchController = TextEditingController();
  final amountCryptoController = TextEditingController();
  final amountFiatController = TextEditingController();
  final manualRateController = TextEditingController();

  bool isBuy = true;
  CryptoCoin? selectedCrypto;
  FiatCurrency? selectedFiat;

  List<CryptoCoin> cryptoSearchResults = [];
  List<FiatCurrency> fiatSearchResults = [];

  bool isCryptoSearching = false;
  bool isPriceLoading = false;
  Timer? _debounce;

  bool isHistoricalTransaction = false;
  DateTime selectedDate = DateTime.now();
  
  Map<String, double> _fiatRates = {};
  bool areRatesLoading = true;
  double _historicalCryptoPriceInUSD = 0.0;
  bool _showManualRateField = false;
  double? _historicalRateFromApi;

  @override
  void initState() {
    super.initState();
    _initializeDialog();
    amountCryptoController.addListener(_calculateFiatFromCrypto);
  }

  Future<void> _initializeDialog() async {
    try {
      final rates = await ApiService.getFiatExchangeRates();
      if (mounted) {
        setState(() {
          _fiatRates = rates.map((key, value) => MapEntry(key.toLowerCase(), value));
          areRatesLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando tasas de cambio: $e");
      if (mounted) setState(() => areRatesLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    cryptoSearchController.dispose();
    fiatSearchController.dispose();
    amountCryptoController.removeListener(_calculateFiatFromCrypto);
    amountCryptoController.dispose();
    amountFiatController.dispose();
    manualRateController.dispose();
    super.dispose();
  }
  
  void _onCryptoSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final searchQuery = query.toLowerCase();
    if (searchQuery.isEmpty) {
      setState(() => cryptoSearchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => isCryptoSearching = true);
      try {
        final apiResults = await ApiService.searchCoins(query);
        final filteredResults = apiResults.where((coin) =>
            coin.name.toLowerCase().startsWith(searchQuery) ||
            coin.ticker.toLowerCase().startsWith(searchQuery)).toList();
        if (mounted) setState(() => cryptoSearchResults = filteredResults);
      } catch (e) {
        print("Error buscando criptomonedas: $e");
      } finally {
        if (mounted) setState(() => isCryptoSearching = false);
      }
    });
  }

  void _onFiatSearchChanged(String query) {
    final searchQuery = query.toLowerCase();
    if (searchQuery.isEmpty) {
      setState(() => fiatSearchResults = []);
      return;
    }
    final results = _supportedFiats.where((fiat) =>
        fiat.name.toLowerCase().startsWith(searchQuery) ||
        fiat.code.toLowerCase().startsWith(searchQuery)).toList();
    setState(() => fiatSearchResults = results);
  }
    Future<void> _onCryptoSelected(CryptoCoin coin) async {
    if (!mounted) return;
    setState(() {
      isPriceLoading = true;
      cryptoSearchResults = [];
      cryptoSearchController.text = coin.ticker;
    });

    try {
      CryptoCoin? coinDetails;
      final existingCoin = widget.marketPrices.where((c) => c.id == coin.id);

      if (existingCoin.isNotEmpty) {
        coinDetails = existingCoin.first;
      } else {
        coinDetails = await ApiService.getCoinDetails(coin.id);
      }
      
      if (mounted && coinDetails != null) {
        setState(() {
          selectedCrypto = coinDetails;
          _calculateFiatFromCrypto();
        });
      }
    } catch (e) {
      print("Error obteniendo detalles de la moneda: $e");
      if (mounted) {
        cryptoSearchController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener el precio de la moneda.')),
        );
      }
    } finally {
      if (mounted) setState(() => isPriceLoading = false);
    }
  }

  void _onFiatSelected(FiatCurrency fiat) {
    setState(() {
      selectedFiat = fiat;
      fiatSearchResults = [];
      fiatSearchController.text = fiat.name;
      _calculateFiatFromCrypto();
    });
  }

  void _calculateFiatFromCrypto() {
    print("\n--- [DEBUG] INICIANDO CÁLCULO ---");
    if (selectedCrypto == null || selectedFiat == null) {
      print("[DEBUG] CÁLCULO DETENIDO: Cripto o Fiat no seleccionada.");
      return;
    }
    final cryptoAmountText = amountCryptoController.text;
    final manualRateText = manualRateController.text;
    final cryptoAmount = double.tryParse(cryptoAmountText);

    print("[DEBUG] Ingredientes del Cálculo:");
    print("  -> Cantidad Crypto (texto): '$cryptoAmountText'");
    print("  -> Es Transacción Histórica?: $isHistoricalTransaction");
    print("  -> Precio Cripto en Tiempo Real (USD): ${selectedCrypto!.price}");
    print("  -> Precio Cripto Histórico (USD): $_historicalCryptoPriceInUSD");
    print("  -> Tasa Fiat (manual, texto): '$manualRateText'");
    print("  -> Tasa Fiat (de API, histórica): $_historicalRateFromApi");
    print("  -> Tasa Fiat (de API, tiempo real): ${_fiatRates[selectedFiat!.code.toLowerCase()]}");
    print("  -> Campo Manual Visible?: $_showManualRateField");

    if (cryptoAmount == null) {
      amountFiatController.clear();
      print("[DEBUG] CÁLCULO DETENIDO: Cantidad de cripto no es un número válido.");
      return;
    }
    final cryptoPriceInUSD = isHistoricalTransaction ? _historicalCryptoPriceInUSD : selectedCrypto!.price;
    if (cryptoPriceInUSD <= 0) {
        amountFiatController.clear();
        print("[DEBUG] CÁLCULO DETENIDO: El precio base de la cripto en USD es cero o negativo.");
        return;
    }
    double exchangeRate = 1.0;
    if (isHistoricalTransaction) {
      if (_showManualRateField) {
        exchangeRate = double.tryParse(manualRateText.replaceAll(',', '.')) ?? 0.0;
        print("[DEBUG]   -> Usando TASA MANUAL: $exchangeRate");
      } else {
        exchangeRate = _historicalRateFromApi ?? 0.0;
        print("[DEBUG]   -> Usando TASA HISTÓRICA DE API: $exchangeRate");
      }
    } else {
      exchangeRate = _fiatRates[selectedFiat!.code.toLowerCase()] ?? 1.0;
      print("[DEBUG]   -> Usando TASA EN TIEMPO REAL: $exchangeRate");
    }
    if (exchangeRate <= 0.0) {
      amountFiatController.clear();
      print("[DEBUG] CÁLCULO DETENIDO: Tasa de cambio es cero o no válida.");
      return;
    }
    final totalValueInUSD = cryptoAmount * cryptoPriceInUSD;
    final totalValueInFiat = totalValueInUSD * exchangeRate;
    
    amountFiatController.text = totalValueInFiat.toStringAsFixed(2);
    print("[DEBUG] CÁLCULO EXITOSO. Valor Fiat: ${amountFiatController.text}\n");
  }

  // --- NOMBRE DE FUNCIÓN CORREGIDO ---
  // En fiat_dialog_widget.dart, reemplaza solo la función _selectDateTime

  Future<void> _selectDateTime() async {
    if (selectedCrypto == null || selectedFiat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona primero la criptomoneda y la moneda fiat.')));
      return;
    }

    final DateTime? pickedDate = await showDatePicker(context: context, locale: const Locale('es', 'ES'), initialDate: selectedDate, firstDate: DateTime(2009), lastDate: DateTime.now());
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
    if (pickedTime == null || !mounted) return;

    final newSelectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    
    setState(() {
      selectedDate = newSelectedDate;
      isPriceLoading = true;
      _showManualRateField = false;
      manualRateController.clear();
      _historicalRateFromApi = null;
      _historicalCryptoPriceInUSD = 0.0;
    });

    try {
      // --- ¡Llamamos a nuestra nueva función "todo en uno"! ---
      final historicalData = await ApiService.getHistoricalData(selectedCrypto!.id, selectedFiat!.code, selectedDate);

      if (mounted) {
        setState(() {
          // Guardamos el precio de la cripto, que ahora SÍ tenemos
          _historicalCryptoPriceInUSD = historicalData.cryptoPriceInUSD;
          
          if (historicalData.fiatExchangeRate == null) {
            // Si la tasa de cambio no vino, mostramos el campo manual
            _showManualRateField = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudo obtener la tasa para ${selectedFiat!.code.toUpperCase()} en esta fecha. Por favor, ingrésala manualmente.'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            // Si vino, la guardamos
            _historicalRateFromApi = historicalData.fiatExchangeRate;
          }
          // En cualquier caso, podemos recalcular porque ahora SIEMPRE tendremos el precio de la cripto
          _calculateFiatFromCrypto();
        });
      }
    } catch (e) {
      print("Error obteniendo datos históricos: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
        // Reseteamos el switch para que el usuario pueda intentarlo de nuevo
        setState(() {
          isHistoricalTransaction = false;
        });
      }
    } finally {
      if (mounted) setState(() => isPriceLoading = false);
    }
  }

  void _launchGoogleSearch() {
    if (selectedFiat == null) return;
    final formattedDate = DateFormat("d 'de' MMMM 'de' yyyy", 'es').format(selectedDate);
    final query = "valor del dolar en ${selectedFiat!.name} el $formattedDate";
    final url = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _registerTransaction() async {
    final cryptoAmount = double.tryParse(amountCryptoController.text);
    final fiatAmount = double.tryParse(amountFiatController.text);
    if (selectedCrypto == null || selectedFiat == null || cryptoAmount == null || fiatAmount == null || cryptoAmount <= 0 || fiatAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos.')));
      return;
    }
    setState(() => isPriceLoading = true);
    try {
      double fiatAmountInUSD;
      if (isHistoricalTransaction) {
        double? exchangeRate;
        if (_showManualRateField) {
          exchangeRate = double.tryParse(manualRateController.text.replaceAll(',', '.'));
          if (exchangeRate == null || exchangeRate <= 0) {
            throw Exception("Por favor, introduce una tasa de cambio manual válida.");
          }
        } else {
          exchangeRate = _historicalRateFromApi;
        }
        if (exchangeRate == null) {
          throw Exception("No se ha podido determinar la tasa de cambio histórica.");
        }
        fiatAmountInUSD = fiatAmount / exchangeRate;
      } else {
        if (selectedFiat!.code.toLowerCase() == 'usd') {
          fiatAmountInUSD = fiatAmount;
        } else {
          final rate = _fiatRates[selectedFiat!.code.toLowerCase()];
          if (rate != null && rate > 0) {
            fiatAmountInUSD = fiatAmount / rate;
          } else {
            throw Exception("No se encontró la tasa de cambio para ${selectedFiat!.code}");
          }
        }
      }
      print("[DEBUG] Registrando Tx: ${fiatAmount.toStringAsFixed(2)} ${selectedFiat!.code.toUpperCase()} -> Equivalente a ${fiatAmountInUSD.toStringAsFixed(2)} USD");
      final newTransaction = Transaction(
        type: isBuy ? 'buy' : 'sell',
        date: isHistoricalTransaction ? selectedDate : DateTime.now(),
        fiatCurrency: selectedFiat!.code,
        fiatAmount: fiatAmount,
        fiatAmountInUSD: fiatAmountInUSD,
        cryptoCoinId: selectedCrypto!.id,
        cryptoAmount: cryptoAmount,
      );
      await FirestoreService.addTransaction(newTransaction);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transacción registrada con éxito.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error al registrar la transacción: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al registrar: $e')));
      }
    } finally {
      if (mounted) setState(() => isPriceLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (areRatesLoading) {
      return const AlertDialog(content: Center(child: CircularProgressIndicator()));
    }
    return AlertDialog(
      title: Text(isBuy ? 'Comprar Crypto con Fiat' : 'Vender Crypto por Fiat'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(title: Text(isBuy ? 'Comprar' : 'Vender'), value: isBuy, onChanged: (value) => setState(() => isBuy = value)),
              const SizedBox(height: 10),
              TextField(
                controller: cryptoSearchController,
                decoration: const InputDecoration(labelText: 'Buscar Criptomoneda', suffixIcon: Icon(Icons.search)),
                onChanged: _onCryptoSearchChanged,
              ),
              if (isCryptoSearching) const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: CircularProgressIndicator()))
              else if (cryptoSearchResults.isNotEmpty) SizedBox(height: 150, child: ListView.builder(itemCount: cryptoSearchResults.length, itemBuilder: (context, index) {
                final coin = cryptoSearchResults[index];
                return ListTile(title: Text(coin.name), subtitle: Text(coin.ticker), onTap: () => _onCryptoSelected(coin));
              })),
              TextField(
                controller: fiatSearchController,
                decoration: const InputDecoration(labelText: 'Buscar Moneda Fiat', suffixIcon: Icon(Icons.search)),
                onChanged: _onFiatSearchChanged,
              ),
              if (fiatSearchResults.isNotEmpty) SizedBox(height: 150, child: ListView.builder(itemCount: fiatSearchResults.length, itemBuilder: (context, index) {
                final fiat = fiatSearchResults[index];
                return ListTile(title: Text(fiat.name), subtitle: Text(fiat.code.toUpperCase()), onTap: () => _onFiatSelected(fiat));
              })),
              if (isPriceLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator()),
              TextField(
                controller: amountCryptoController,
                decoration: InputDecoration(labelText: 'Cantidad ${selectedCrypto?.ticker ?? 'Crypto'}'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: amountFiatController,
                decoration: InputDecoration(labelText: 'Cantidad ${selectedFiat?.code.toUpperCase() ?? 'Fiat'} (Calculado)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                readOnly: true,
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Transacción Histórica'),
                value: isHistoricalTransaction,
                onChanged: (bool value) {
                  setState(() {
                    isHistoricalTransaction = value;
                    _showManualRateField = false;
                    if (value && selectedCrypto != null && selectedFiat != null) {
                      _selectDateTime();
                    }
                  });
                },
              ),
              if (isHistoricalTransaction)
                ElevatedButton.icon(
                  onPressed: _selectDateTime, // <-- LLAMADA CORREGIDA
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('dd-MM-yyyy HH:mm', 'es').format(selectedDate)),
                ),
              if (_showManualRateField)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No pudimos obtener la tasa en esta fecha. Por favor, ingrésala manualmente:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: manualRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Tasa (1 USD = ? ${selectedFiat?.code.toUpperCase()})',
                                hintText: 'Ej: 4409.57',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: (){
                              FocusScope.of(context).unfocus();
                              _calculateFiatFromCrypto();
                            },
                            child: const Text('Calcular'),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _launchGoogleSearch,
                        child: const Text('Buscar tasa en Google', style: TextStyle(decoration: TextDecoration.underline)),
                      )
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _registerTransaction, child: const Text('Registrar')),
      ],
    );
  }
}