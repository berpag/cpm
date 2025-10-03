// lib/presentation/screens/dashboard/widgets/crypto_coin_card.dart

import 'package:cpm/data/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:cpm/data/models/coin_models.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  // Función auxiliar para formatear contratos
  String _formatContract(String? contract) {
    if (contract == null || contract.length < 8) return contract ?? '...';
    return '${contract.substring(0, 4)}...${contract.substring(contract.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<Set<String>>(
        stream: FirestoreService.getFiatListStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()));
          }
          
          final kFiatTickers = snapshot.data!;
          final bool isFiat = kFiatTickers.contains(asset.ticker.toUpperCase());
          
          // Lógica para mostrar datos parciales o completos
          final bool isEnriched = !marketCoin.id.startsWith('unknown_');
          final String displayTicker = isEnriched ? marketCoin.ticker : _formatContract(asset.rawContract);
          final String displayName = isEnriched ? marketCoin.name : (asset.rawNetwork?.toUpperCase() ?? 'Desconocido');

          final formatNumber = NumberFormat('#,##0.########', 'en_US');
          final formatPriceUSD = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 4);
          final formatCurrencyUSD = NumberFormat.currency(locale: 'en_US', symbol: '\$');
          
          final double currentHoldingValue = isFiat ? asset.totalAmount : asset.totalAmount * marketCoin.price;
          final double pnlValue = currentHoldingValue - asset.totalInvestedUSD;
          final double pnlPercent = (asset.totalInvestedUSD > 0) ? (pnlValue / asset.totalInvestedUSD) * 100 : 0.0;
          final pnlColor = pnlValue >= 0 ? Colors.green : Colors.red;

          return ExpansionTile(
            title: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: (isEnriched && marketCoin.logoUrl != null && marketCoin.logoUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: marketCoin.logoUrl!,
                        placeholder: (context, url) => const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        ),
                        errorWidget: (context, url, error) => CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          child: Text(displayTicker.isNotEmpty ? displayTicker[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        imageBuilder: (context, imageProvider) => CircleAvatar(
                          backgroundImage: imageProvider,
                          backgroundColor: Colors.transparent,
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: isFiat ? Colors.blueGrey : Colors.amber, 
                        child: Text(displayTicker.isNotEmpty ? displayTicker[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayTicker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        displayName, 
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrencyUSD.format(currentHoldingValue), 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    Text(isFiat ? "Balance" : "Valor Holding", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 16.0),
            shape: const Border(top: BorderSide.none, bottom: BorderSide.none),
            
            children: [
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 12),

              ...asset.balances.entries.map((entry) {
                final walletName = entry.key;
                final balance = entry.value;
                if (balance.abs() < 1e-9) return const SizedBox.shrink();
                return _buildInfoRow(walletName, formatNumber.format(balance));
              }),
              
              if (asset.balances.length > 1) const Divider(height: 16, thickness: 0.5),
              
              _buildInfoRow('Total Holding', formatNumber.format(asset.totalAmount), isBold: true),

              if (!isFiat) ...[
                _buildInfoRow('Inversión', formatCurrencyUSD.format(asset.totalInvestedUSD)),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("P/L", style: TextStyle(color: Colors.grey)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCurrencyUSD.format(pnlValue),
                            style: TextStyle(fontWeight: FontWeight.bold, color: pnlColor),
                          ),
                          Text(
                            '${pnlPercent.toStringAsFixed(2)}%',
                            style: TextStyle(fontSize: 12, color: pnlColor),
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
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
              ]
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? null : Colors.grey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? null : Colors.grey[600])),
        ],
      ),
    );
  }
}