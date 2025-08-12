import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';

class CryptoCoinCard extends StatelessWidget {
  final PortfolioAsset asset;
  final CryptoCoin marketCoin;

  const CryptoCoinCard({
    super.key,
    required this.asset,
    required this.marketCoin,
  });

  @override
  Widget build(BuildContext context) {
    final double currentHoldingValue = asset.amount * marketCoin.price;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // --- Columna Izquierda (Info del Activo) ---
          const Icon(Icons.monetization_on, color: Colors.amber, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.ticker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(asset.name, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '${asset.amount.toString()} monedas',
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // --- Columna Derecha (Valores Monetarios) ---
          // ¡AQUÍ ESTÁ LA MODIFICACIÓN!
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Grupo 1: Precio Actual del Mercado
              Text(
                '\$${marketCoin.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Precio Actual', // <-- NUEVO SUBTÍTULO
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 8), // Espacio entre los dos grupos de valores

              // Grupo 2: Valor Total del Holding
              Text(
                '\$${currentHoldingValue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const Text(
                'Valor Holding', // <-- NUEVO SUBTÍTULO
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}