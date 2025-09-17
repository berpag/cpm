// lib/presentation/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cpm/presentation/screens/settings/fiat_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.money),
            title: const Text('Monedas Fiat'),
            subtitle: const Text('Añadir o quitar monedas fiat de la lista'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FiatSettingsScreen()),
              );
            },
          ),
          // Aquí podremos añadir más opciones de configuración en el futuro
        ],
      ),
    );
  }
}