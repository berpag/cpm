// lib/presentation/screens/dashboard/widgets/crypto_coin_card.dart

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
    // --- CÁLCULOS DE P/L ---
    final double currentHoldingValue = (asset.amount ?? 0.0) * marketCoin.price;
    final double pnlUSD = currentHoldingValue - asset.totalInvestedUSD;
    // Evitamos la división por cero si el total invertido es 0.
    final double pnlPercent = asset.totalInvestedUSD > 0
        ? (pnlUSD / asset.totalInvestedUSD) * 100
        : 0.0;

    // Determinamos el color basado en si hay ganancia o pérdida.
    final Color pnlColor = pnlUSD >= 0 ? Colors.green : Colors.red;
    final IconData pnlIcon = pnlUSD >= 0 ? Icons.arrow_upward : Icons.arrow_downward;

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
                  '${(asset.amount ?? 0.0).toString()} monedas',
                  style: TextStyle(
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${marketCoin.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Precio Actual',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${currentHoldingValue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const Text(
                'Valor Holding',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              
              // --- ¡NUEVA SECCIÓN DE P/L! ---
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(pnlIcon, color: pnlColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${pnlUSD.toStringAsFixed(2)} USD (${pnlPercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      color: pnlColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}