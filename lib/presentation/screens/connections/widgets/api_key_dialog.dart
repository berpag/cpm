// lib/presentation/screens/connections/widgets/api_key_dialog.dart

import 'package:flutter/material.dart';

class ApiKeyDialog extends StatefulWidget {
  final String exchangeName;

  const ApiKeyDialog({
    super.key,
    required this.exchangeName,
  });

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  final _apiKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  bool _isSecretVisible = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  void _saveKeys() {
    final apiKey = _apiKeyController.text.trim();
    final secretKey = _secretKeyController.text.trim();

    if (apiKey.isEmpty || secretKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduce ambas claves.'), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.of(context).pop({
      'apiKey': apiKey,
      'secretKey': secretKey,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // --- CORREGIDO: 'const' eliminado de aquí ---
      title: Text('Conectar con ${widget.exchangeName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CORREGIDO: 'const' eliminado de aquí ---
            Text('Introduce tus claves API generadas en la web de ${widget.exchangeName}.'),
            const SizedBox(height: 8),
            Text(
              'IMPORTANTE: Asegúrate de que la clave tenga permisos de "Solo Lectura".',
              style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secretKeyController,
              obscureText: !_isSecretVisible,
              decoration: InputDecoration(
                labelText: 'Secret Key',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_isSecretVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isSecretVisible = !_isSecretVisible;
                    });
                  },
                ),
              ),
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
          onPressed: _saveKeys,
          child: const Text('Guardar y Verificar'),
        ),
      ],
    );
  }
}