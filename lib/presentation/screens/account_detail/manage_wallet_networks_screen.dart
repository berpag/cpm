// lib/presentation/screens/account_detail/manage_wallet_networks_screen.dart

import 'package:flutter/material.dart';
import 'package:cpm/data/services/firestore_service.dart';

class ManageWalletNetworksScreen extends StatefulWidget {
  final String walletName;
  const ManageWalletNetworksScreen({super.key, required this.walletName});

  @override
  State<ManageWalletNetworksScreen> createState() => _ManageWalletNetworksScreenState();
}

class _ManageWalletNetworksScreenState extends State<ManageWalletNetworksScreen> {
  Map<String, String> _networks = {};
  bool _isLoading = true;

  // --- ¡LISTA FINAL DE REDES SOPORTADAS! ---
  final Map<String, String> _networkDisplayNames = {
    'evm': 'EVM (Ethereum, Polygon, etc)',
    'solana': 'Solana',
    'bitcoin': 'Bitcoin',
    'xrp': 'XRP (Ripple)',
    'stellar': 'Stellar (XLM)',
    'hedera': 'Hedera (HBAR)',
    'near': 'NEAR Protocol',
    'cardano': 'Cardano (ADA)',
    'bittensor': 'Bittensor (TAO)',
    'mode': 'Mode Network',
  };

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    setState(() => _isLoading = true);
    final networks = await FirestoreService.getWalletNetworks(widget.walletName);
    if (mounted) {
      setState(() {
        _networks = networks;
        _isLoading = false;
      });
    }
  }
  
  // --- ¡REGLAS DE DETECCIÓN FINALES! ---
  String _detectNetworkType(String address) {
    address = address.trim();
    if (address.startsWith('0x') && address.length == 42) {
      // EVM es la más común con este formato, así que la comprobamos primero
      return 'evm'; 
    } else if (address.startsWith('bc1') || address.startsWith('1') || address.startsWith('3')) {
      return 'bitcoin';
    } else if (address.startsWith('r') && address.length > 25) {
      return 'xrp';
    } else if (address.startsWith('G') && address.length == 56) {
      return 'stellar';
    } else if (RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$').hasMatch(address)) { // Formato 0.0.12345
      return 'hedera';
    } else if (address.endsWith('.near') || (address.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(address))) { // Formato xxx.near o hash de 64 chars
      return 'near';
    } else if (address.startsWith('addr1')) {
      return 'cardano';
    } else if (address.startsWith('5') && address.length > 40) { // Formato SS58
      return 'bittensor';
    }
     else if (address.length >= 32 && address.length <= 44 && !address.contains(' ')) {
      return 'solana'; // La dejamos como una de las últimas por ser menos específica
    } else {
      return 'unknown';
    }
  }

  Future<void> _showAddOrEditNetworkDialog({String? existingNetworkKey}) async {
    final addressController = TextEditingController(
      text: existingNetworkKey != null ? _networks[existingNetworkKey] : ''
    );
    String detectedNetworkKey = existingNetworkKey ?? 'unknown';
    bool isManualOverride = false;

    if (existingNetworkKey != null) {
      detectedNetworkKey = existingNetworkKey;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            if (existingNetworkKey != null) {
              return AlertDialog(
                title: Text('Editar Dirección de ${_networkDisplayNames[existingNetworkKey] ?? ''}'),
                content: TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Dirección Pública'),
                  autofocus: true,
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'networkKey': existingNetworkKey,
                        'address': addressController.text.trim(),
                      });
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              );
            }

            final availableNetworksForDropdown = _networkDisplayNames.entries
                .where((entry) => !_networks.containsKey(entry.key))
                .toList();
            
            return AlertDialog(
              title: const Text('Añadir Nueva Red'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Pega la dirección aquí'),
                      onChanged: (value) {
                        setDialogState(() {
                          detectedNetworkKey = _detectNetworkType(value);
                          isManualOverride = false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    if (detectedNetworkKey != 'unknown' && !isManualOverride) ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Red detectada: ${_networkDisplayNames[detectedNetworkKey]}')),
                        ],
                      ),
                      TextButton(
                        onPressed: () => setDialogState(() => isManualOverride = true),
                        child: const Text('¿No es correcto? Cambiar manualmente'),
                      )
                    ] else if (isManualOverride || (addressController.text.isNotEmpty && detectedNetworkKey == 'unknown')) ...[
                      const Text('Por favor, selecciona la red correcta:'),
                      if (availableNetworksForDropdown.isNotEmpty)
                        DropdownButton<String>(
                          value: detectedNetworkKey != 'unknown' && availableNetworksForDropdown.any((e) => e.key == detectedNetworkKey)
                              ? detectedNetworkKey
                              : availableNetworksForDropdown.first.key,
                          isExpanded: true,
                          items: availableNetworksForDropdown.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              detectedNetworkKey = newValue!;
                            });
                          },
                        )
                      else
                        const Text('Ya has añadido todas las redes soportadas.', style: TextStyle(color: Colors.grey)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: detectedNetworkKey != 'unknown' && !_networks.containsKey(detectedNetworkKey)
                    ? () {
                        Navigator.of(context).pop({
                          'networkKey': detectedNetworkKey,
                          'address': addressController.text.trim(),
                        });
                      }
                    : null,
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result['address']!.isNotEmpty) {
      final networkKey = result['networkKey']!;
      final newNetworks = Map<String, String>.from(_networks);
      newNetworks[networkKey] = result['address']!;
      await FirestoreService.saveWalletNetworks(widget.walletName, newNetworks);
      _loadNetworks();
    }
  }
  
  Future<void> _deleteNetwork(String networkKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar la dirección de la red ${networkKey.toUpperCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _networks.remove(networkKey);
      });

      try {
        await FirestoreService.saveWalletNetworks(widget.walletName, _networks);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Red ${networkKey.toUpperCase()} eliminada.'), backgroundColor: Colors.green)
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red)
        );
        _loadNetworks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurar Redes de ${widget.walletName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _networks.length,
              itemBuilder: (context, index) {
                final networkKey = _networks.keys.elementAt(index);
                final address = _networks[networkKey]!;
                final maskedAddress = address.length > 10
                    ? '${address.substring(0, 6)}...${address.substring(address.length - 4)}'
                    : address;
                
                final displayName = _networkDisplayNames[networkKey] ?? networkKey.toUpperCase();

                return Card(
                  child: ListTile(
                    title: Text(displayName),
                    subtitle: Text(maskedAddress),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAddOrEditNetworkDialog(existingNetworkKey: networkKey),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteNetwork(networkKey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _networks.length < _networkDisplayNames.length 
          ? () => _showAddOrEditNetworkDialog() 
          : null,
        backgroundColor: _networks.length < _networkDisplayNames.length ? Theme.of(context).colorScheme.secondary : Colors.grey,
        child: const Icon(Icons.add),
      ),
    );
  }
}