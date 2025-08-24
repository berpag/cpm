// lib/presentation/screens/connections/binance_options_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:cpm/data/services/api_service.dart';
import 'package:cpm/data/services/binance_api_service.dart';
import 'package:cpm/data/services/firestore_service.dart';
import 'package:cpm/data/utils/binance_csv_parser.dart';
import 'package:cpm/data/utils/transaction_converter.dart';
import 'package:cpm/presentation/screens/connections/widgets/api_key_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';

class BinanceOptionsScreen extends StatefulWidget {
  // Ahora es un StatefulWidget para poder manejar su propio estado
  final ApiConnection? binanceConnection;

  const BinanceOptionsScreen({
    super.key,
    required this.binanceConnection,
  });

  @override
  State<BinanceOptionsScreen> createState() => _BinanceOptionsScreenState();
}

class _BinanceOptionsScreenState extends State<BinanceOptionsScreen> {
  bool _isLoading = false;
  String _loadingMessage = '';
  // Estado local para reflejar los cambios sin tener que recargar toda la pantalla anterior
  ApiConnection? _currentConnection;

  @override
  void initState() {
    super.initState();
    _currentConnection = widget.binanceConnection;
  }

  // --- LÓGICA DE CONEXIÓN/DESCONEXIÓN ---
  Future<void> _showApiKeyDialog() async {
    final result = await showDialog<Map<String, String>>(context: context, barrierDismissible: false, builder: (context) => const ApiKeyDialog(exchangeName: 'Binance'));
    if (result != null) {
      final apiKey = result['apiKey']!;
      final secretKey = result['secretKey']!;
      setState(() { _isLoading = true; _loadingMessage = 'Verificando claves...'; });
      try {
        await BinanceApiService.getAccountInfo(apiKey: apiKey, secretKey: secretKey);
        await FirestoreService.saveApiKey(exchangeName: 'Binance', apiKey: apiKey, secretKey: secretKey);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Binance conectado con éxito!'), backgroundColor: Colors.green));
          // Actualizamos el estado local
          setState(() {
            _currentConnection = ApiConnection(exchangeName: 'Binance', apiKey: apiKey);
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al conectar: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disconnectApi() async {
     setState(() { _isLoading = true; _loadingMessage = 'Desconectando...'; });
     try {
       await FirestoreService.deleteConnection('Binance');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Binance desconectado.'), backgroundColor: Colors.grey));
         setState(() {
           _currentConnection = null;
         });
       }
     } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al desconectar: $e'), backgroundColor: Colors.red));
     } finally {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  // --- ¡EL ORQUESTADOR DE IMPORTACIÓN HÍBRIDA! ---
  Future<void> _startHybridImport() async {
    if (_currentConnection == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, conecta tu API de Binance primero.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() { _isLoading = true; _loadingMessage = 'Selecciona tu archivo de "Registros de Transacciones"...'; });
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.single.bytes == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final bytes = result.files.single.bytes!;
      final csvString = utf8.decode(bytes);
      final List<Transaction> allNewTransactions = [];
      final marketPrices = await ApiService.getCoins();

      setState(() => _loadingMessage = 'Paso 1/4: Analizando archivo CSV...');
      final csvData = _extractSymbolsAndStartDateFromCsv(csvString);
      final symbolsToSync = csvData['symbols'] as Set<String>;
      final startTime = csvData['startDate'] as DateTime;
      
      final apiKey = _currentConnection!.apiKey;
      final secretKey = await FirestoreService.getSecretKeyFor('Binance');
      if (secretKey == null) throw Exception('No se encontró la Secret Key.');

      final List<String> symbolsList = symbolsToSync.toList();
      for (int i = 0; i < symbolsList.length; i++) {
        final symbol = symbolsList[i];
        if (mounted) setState(() => _loadingMessage = 'Paso 2/4: Sincronizando trades de ${symbol} (${i + 1}/${symbolsList.length})...');
        await Future.delayed(const Duration(milliseconds: 500));
        final trades = await BinanceApiService.getTradeHistory(apiKey: apiKey, secretKey: secretKey, symbol: symbol, startTime: startTime.millisecondsSinceEpoch);
        for (final trade in trades) {
          final convertedTxs = await TransactionConverter.fromBinanceTrade(trade, marketPrices);
          allNewTransactions.addAll(convertedTxs);
        }
      }

      if (mounted) setState(() => _loadingMessage = 'Paso 3/4: Procesando depósitos, retiros y otros del CSV...');
      final nonTradeTransactions = await BinanceCsvParser.parse(csvString);
      allNewTransactions.addAll(nonTradeTransactions);
      
      if (mounted) setState(() => _loadingMessage = 'Paso 4/4: Guardando ${allNewTransactions.length} transacciones...');
      if (allNewTransactions.isNotEmpty) {
        await FirestoreService.addTransactionsBatch(allNewTransactions);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Importación completa! Se procesaron ${allNewTransactions.length} nuevas transacciones.'), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error durante la importación: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _extractSymbolsAndStartDateFromCsv(String csvContent) {
    // ... (Esta función no cambia)
    final Set<String> symbols = {};
    DateTime startDate = DateTime.now();
    final converter = CsvToListConverter(fieldDelimiter: ',', eol: '\n');
    final List<List<dynamic>> rows = converter.convert(csvContent);
    if (rows.length < 2) return {'symbols': symbols, 'startDate': startDate};
    startDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(rows.last[1].toString(), true).toUtc();
    for (int i = 1; i < rows.length; i++) {
      final operation = rows[i][3].toString();
      if (operation == 'Transaction Buy' || operation == 'Transaction Sold') {
          // Lógica simple para extraer el par. Ej: BTCUSDT
          // Podríamos necesitar una lógica más robusta aquí.
          // Por ahora, asumimos que la moneda de cotización es la que aparece en el 'spend'.
          String? quoteTicker;
          for(int j=i-1; j>0 && rows[j][1] == rows[i][1]; j--){
            if(rows[j][3] == 'Transaction Spend'){
              quoteTicker = rows[j][4];
              break;
            }
          }
          if(quoteTicker != null){
            symbols.add('${rows[i][4]}$quoteTicker');
          }
      }
    }
    return {'symbols': symbols, 'startDate': startDate};
  }
  
  // -- FUNCIÓN DE SINCRONIZACIÓN MOVIDA AQUÍ ---
  Future<void> _syncAllTrades() async {
    // ... (La lógica de sync es la misma que tenías en connections_screen)
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _currentConnection != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Opciones de Binance'),
        backgroundColor: const Color(0xFF1a237e),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              ListTile(
                leading: Icon(Icons.key, color: isConnected ? Colors.green : Colors.grey),
                title: Text(isConnected ? 'API Conectada' : 'Conectar API'),
                subtitle: Text(isConnected ? 'Puedes sincronizar o desconectar' : 'Permite sincronizar trades recientes'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: isConnected ? _disconnectApi : _showApiKeyDialog,
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.file_upload, color: Theme.of(context).primaryColor),
                title: const Text('Importar Historial Completo'),
                subtitle: const Text('Usa un archivo CSV y la API para la máxima precisión'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _isLoading ? null : _startHybridImport,
              ),
              const Divider(),
              if (isConnected)
                ListTile(
                  leading: Icon(Icons.sync, color: Theme.of(context).primaryColor),
                  title: const Text('Sincronizar Trades Recientes'),
                  subtitle: const Text('Busca nuevas transacciones desde la última sincronización'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _syncAllTrades(), // TODO: Mover la lógica aquí
                ),
            ],
          ),
          if (_isLoading)
            Container( // Loader
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}