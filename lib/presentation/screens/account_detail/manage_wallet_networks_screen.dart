// lib/presentation/screens/account_detail/manage_wallet_networks_screen.dart

import 'package:flutter/material.dart'; // <-- ¡ESTA ES LA LÍNEA QUE FALTABA!
import 'package:cpm/data/services/secure_storage_service.dart';

class ManageWalletNetworksScreen extends StatefulWidget {
  final String walletName;
  const ManageWalletNetworksScreen({super.key, required this.walletName});

  @override
  State<ManageWalletNetworksScreen> createState() => _ManageWalletNetworksScreenState();
}

class _ManageWalletNetworksScreenState extends State<ManageWalletNetworksScreen> {
  Map<String, String> _networks = {};
  bool _isLoading = true;

  final List<String> _supportedNetworks = ['Solana', 'EVM (Ethereum, Polygon, etc)', 'Bitcoin'];

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    final networks = await SecureStorageService.getWalletNetworks(widget.walletName);
    if (mounted) {
      setState(() {
        _networks = networks;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddOrEditNetworkDialog({String? existingNetworkKey}) async {
    String? selectedNetworkDisplay = existingNetworkKey != null
      ? _supportedNetworks.firstWhere(
          (n) => n.split(' ').first.toLowerCase() == existingNetworkKey,
          orElse: () => existingNetworkKey.toUpperCase()
        )
      : null;

    final addressController = TextEditingController(
      text: existingNetworkKey != null ? _networks[existingNetworkKey] : ''
    );
    
    final availableNetworks = _supportedNetworks.where(
      (n) => !_networks.containsKey(n.split(' ').first.toLowerCase())
    ).toList();
    
    if (existingNetworkKey == null && availableNetworks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya has añadido todas las redes soportadas.'), backgroundColor: Colors.blue)
      );
      return;
    }

    if (existingNetworkKey == null) {
      selectedNetworkDisplay = availableNetworks.first;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingNetworkKey == null ? 'Añadir Red' : 'Editar Red'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (existingNetworkKey != null)
                    Text(selectedNetworkDisplay!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  else
                    DropdownButton<String>(
                      value: selectedNetworkDisplay,
                      isExpanded: true,
                      items: availableNetworks.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() {
                          selectedNetworkDisplay = newValue!;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Dirección Pública'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'network': selectedNetworkDisplay!,
                      'address': addressController.text.trim(),
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result['address']!.isNotEmpty) {
      final networkKey = result['network']!.split(' ').first.toLowerCase();
      final newNetworks = Map<String, String>.from(_networks);
      newNetworks[networkKey] = result['address']!;
      await SecureStorageService.saveWalletNetworks(widget.walletName, newNetworks);
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

    if (confirm == true) {
      final newNetworks = Map<String, String>.from(_networks);
      newNetworks.remove(networkKey);
      await SecureStorageService.saveWalletNetworks(widget.walletName, newNetworks);
      _loadNetworks();
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
                
                final displayName = _supportedNetworks.firstWhere(
                  (n) => n.split(' ').first.toLowerCase() == networkKey,
                  orElse: () => networkKey.toUpperCase()
                );

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
        onPressed: _networks.length < _supportedNetworks.length 
          ? _showAddOrEditNetworkDialog 
          : null,
        backgroundColor: _networks.length < _supportedNetworks.length ? Theme.of(context).colorScheme.secondary : Colors.grey,
        child: const Icon(Icons.add),
      ),
    );
  }
}