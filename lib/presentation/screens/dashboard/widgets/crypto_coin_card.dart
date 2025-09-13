// lib/presentation/screens/dashboard/widgets/crypto_coin_card.dart

import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';

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
    final formatCurrency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final formatNumber = NumberFormat('#,##0.########');

    final double currentHoldingValue = asset.totalAmount * marketCoin.price;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Fila Superior: Identidad del Activo y Valor Total ---
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Text(
                    // Usa la primera letra del Ticker para el avatar
                    asset.ticker.isNotEmpty ? asset.ticker[0] : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- CAMBIO CLAVE AQUÍ ---
                      // Texto grande y en negrita usa el Ticker (ej: BNB)
                      Text(asset.ticker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      // Texto pequeño y gris usa el Nombre completo (ej: BNB)
                      // Nota: Para algunas monedas como COP, ambos pueden ser iguales si no hay un nombre completo definido.
                      Text(asset.name, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  formatCurrency.format(currentHoldingValue),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // --- Filas de Desglose por Billetera (Spot, Earn, etc.) ---
            ...asset.balances.entries.map((entry) {
              final walletName = entry.key;
              final balance = entry.value;
              if (balance.abs() < 0.00000001) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(walletName, style: const TextStyle(color: Colors.grey)),
                    Text(formatNumber.format(balance), style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
            
            // --- Separador si hay más de una billetera ---
            if (asset.balances.length > 1) const Divider(height: 16),
            
            // --- Fila del Total Combinado ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Holding', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(formatNumber.format(asset.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),

            // TODO: Aquí irá la sección de P/L y Precio Promedio cuando la implementemos.
          ],
        ),
      ),
    );
  }
}