// lib/data/utils/base_calculator.dart

import 'package:cpm/data/models/coin_models.dart';

/// Define el contrato que todos los calculadores de portafolio específicos por fuente deben seguir.
/// Cada calculador tomará una lista de *sus propias* transacciones y las procesará.
abstract class BasePortfolioCalculator {
  
  /// Procesa una lista de transacciones de una fuente específica y las agrupa en activos de portafolio.
  /// 
  /// [transactions]: La lista de transacciones que pertenecen *únicamente* a esta fuente.
  /// [marketPrices]: La lista completa de precios de mercado actuales para calcular el valor.
  /// 
  /// Devuelve un `Future` que se resuelve en una lista de `PortfolioAsset`.
  Future<List<PortfolioAsset>> calculate({
    required List<Transaction> transactions,
    required List<CryptoCoin> marketPrices,
  });
}