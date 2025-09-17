// lib/presentation/screens/settings/fiat_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cpm/data/services/firestore_service.dart';

class FiatSettingsScreen extends StatelessWidget {
  const FiatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Monedas Fiat'),
      ),
      body: StreamBuilder<Set<String>>(
        stream: FirestoreService.getFiatListStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final fiatList = snapshot.data!.toList()..sort();

          return ListView.builder(
            itemCount: fiatList.length,
            itemBuilder: (context, index) {
              final ticker = fiatList[index];
              return ListTile(
                title: Text(ticker),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    final updatedList = snapshot.data!..remove(ticker);
                    FirestoreService.updateFiatList(updatedList);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddFiatDialog(context),
      ),
    );
  }

  Future<void> _showAddFiatDialog(BuildContext context) async {
    final controller = TextEditingController();
    final newTicker = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Moneda Fiat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 4, // Aumentado por si acaso
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Ticker (ej. USD)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Añadir')),
        ],
      ),
    );

    if (newTicker != null && newTicker.trim().isNotEmpty) {
      final currentList = await FirestoreService.getFiatListStream().first;
      final updatedList = currentList..add(newTicker.trim().toUpperCase());
      await FirestoreService.updateFiatList(updatedList);
    }
  }
}