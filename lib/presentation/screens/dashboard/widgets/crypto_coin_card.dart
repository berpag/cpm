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
        
        // --- FORMATEADORES ---
        final formatNumber = NumberFormat('#,##0.########', 'en_US');
        final formatPriceUSD = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 4);
        final formatCurrencyUSD = NumberFormat.currency(locale: 'en_US', symbol: '\$'); // Para valores grandes
        final formatFiatLocal = NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 2);
        
        // --- CÁLCULOS PARA LA NUEVA UI ---
        final double currentHoldingValue = isFiat ? asset.totalAmount : asset.totalAmount * marketCoin.price;
        final double pnlValue = currentHoldingValue - asset.totalInvestedUSD;
        final double pnlPercent = (asset.totalInvestedUSD > 0) ? (pnlValue / asset.totalInvestedUSD) * 100 : 0.0;
        final pnlColor = pnlValue >= 0 ? Colors.green : Colors.red;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- FILA SUPERIOR REESTRUCTURADA ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Columna Izquierda: Logo y Ticker ---
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isFiat ? Colors.blueGrey : Colors.amber, 
                          child: Text(asset.ticker.isNotEmpty ? asset.ticker[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(asset.ticker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(asset.name, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(), // Ocupa el espacio del medio

                    // --- Columna Central: Precio Actual ---
                    if (!isFiat)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            formatPriceUSD.format(marketCoin.price),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Text("Precio Actual", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    
                    const Spacer(), // Ocupa el espacio del medio

                    // --- Columna Derecha: Valor del Holding ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isFiat ? formatFiatLocal.format(currentHoldingValue) : formatCurrencyUSD.format(currentHoldingValue), 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        Text(isFiat ? "Balance" : "Valor Holding", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                
                // --- FILAS DE DETALLE ---
                ...asset.balances.entries.map((entry) {
                  final walletName = entry.key;
                  final balance = entry.value;
                  if (balance.abs() < 1e-9) return const SizedBox.shrink();
                  return _buildInfoRow(walletName, formatNumber.format(balance));
                }),
                
                if (asset.balances.length > 1) const Divider(height: 16),
                
                _buildInfoRow('Total Holding', formatNumber.format(asset.totalAmount), isBold: true),

                if (!isFiat) ...[
                  _buildInfoRow('Inversión', formatCurrencyUSD.format(asset.totalInvestedUSD)),
                  
                  // --- FILA NUEVA PARA P/L (Profit/Loss) ---
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

                  // Fila para el Precio Promedio de Compra con botón de editar
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
            ),
          ),
        );
      }
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