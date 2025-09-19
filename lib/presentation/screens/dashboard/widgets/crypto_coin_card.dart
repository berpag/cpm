// lib/presentation/screens/dashboard/widgets/crypto_coin_card.dart

import 'package:cpm/data/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';

class CryptoCoinCard extends StatelessWidget {
  final PortfolioAsset asset;
  final CryptoCoin marketCoin;
  final VoidCallback? onEdit;

  const CryptoCoinCard({
    super.key,
    required this.asset,
    required this.marketCoin,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: FirestoreService.getFiatListStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator())));
        }
        
        final kFiatTickers = snapshot.data!;
        final bool isFiat = kFiatTickers.contains(asset.ticker.toUpperCase());
        
        // --- FORMATEADORES CORREGIDOS Y SIMPLIFICADOS ---
        final formatNumber = NumberFormat('#,##0.########', 'en_US');
        
        // Usamos el constructor .currency que es más seguro y maneja los símbolos correctamente
        final formatPriceUSD = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 4);
        
        final formatFiatLocal = NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 2);
        
        final double currentHoldingValue = isFiat ? asset.totalAmount : asset.totalAmount * marketCoin.price;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isFiat ? Colors.blueGrey : Colors.amber, 
                      child: Text(asset.ticker.isNotEmpty ? asset.ticker[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asset.ticker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(asset.name, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                      isFiat ? formatFiatLocal.format(currentHoldingValue) : formatPriceUSD.format(currentHoldingValue), 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
                const Divider(height: 24),
                
                ...asset.balances.entries.map((entry) {
                  final walletName = entry.key;
                  final balance = entry.value;
                  if (balance.abs() < 1e-9) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(walletName, style: const TextStyle(color: Colors.grey)),
                      Text(formatNumber.format(balance), style: const TextStyle(color: Colors.grey)),
                    ]),
                  );
                }),
                
                if (asset.balances.length > 1) const Divider(height: 16),
                
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total Holding', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(formatNumber.format(asset.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),

                if (!isFiat)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Precio Prom. Compra', style: TextStyle(color: Colors.grey)),
                        Row(
                          children: [
                            Text(formatPriceUSD.format(asset.averageBuyPrice), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            if (onEdit != null)
                              SizedBox(
                                height: 24, width: 24,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 16,
                                  icon: const Icon(Icons.edit, color: Colors.grey),
                                  onPressed: onEdit,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    );
  }
}