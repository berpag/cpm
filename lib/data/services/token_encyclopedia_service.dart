// lib/data/services/token_encyclopedia_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Este es el modelo de datos para un documento en nuestra enciclopedia.
class TokenInfo {
  final String id; // ej: 'chainx'
  final String name; // ej: 'CHEX Token'
  final String symbol; // ej: 'CHEX'
  final String? logoUrl;
  // Mapa de plataformas a direcciones de contrato.
  final Map<String, String> platforms; 

  TokenInfo({
    required this.id,
    required this.name,
    required this.symbol,
    this.logoUrl,
    this.platforms = const {},
  });

  // Convierte un objeto TokenInfo a un mapa para guardarlo en Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'logoUrl': logoUrl,
      'platforms': platforms,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Crea un objeto TokenInfo a partir de un mapa de Firestore.
  factory TokenInfo.fromFirestore(Map<String, dynamic> data) {
    String? logoUrl = data['logoUrl'];
    // --- LÓGICA DE FALLBACK AÑADIDA ---
    if ((logoUrl == null || logoUrl.isEmpty) && data['id'] == 'ethereum') {
      logoUrl = 'https://assets.coingecko.com/coins/images/279/large/ethereum.png';
    }
    // ------------------------------------
    return TokenInfo(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      symbol: data['symbol'] ?? '',
      logoUrl: logoUrl, // Usamos la variable local que puede tener el fallback
      platforms: Map<String, String>.from(data['platforms'] ?? {}),
    );
  }
}


class TokenEncyclopediaService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  // La referencia a nuestra nueva colección. La creará automáticamente.
  static CollectionReference get _tokensCollection => _db.collection('tokens');

  /// Guarda o actualiza la información de un token en la enciclopedia.
  /// Usamos el coinId como el ID del documento para evitar duplicados.
  static Future<void> saveTokenInfo(TokenInfo token) async {
    // Usamos `set` con `merge: true` para que si el token ya existe,
    // solo actualice los campos nuevos o modificados (como añadir una nueva plataforma).
    await _tokensCollection.doc(token.id).set(token.toFirestore(), SetOptions(merge: true));
    print('[Encyclopedia] Información guardada/actualizada para ${token.symbol} (${token.id})');
  }

  /// Busca la información de un token por su coinId.
  static Future<TokenInfo?> getTokenInfoById(String coinId) async {
    final doc = await _tokensCollection.doc(coinId).get();
    if (doc.exists) {
      return TokenInfo.fromFirestore(doc.data() as Map<String, dynamic>);
    }
    return null; // Devuelve null si no está en nuestra enciclopedia.
  }

  /// Busca la información de un token por la dirección de su contrato en una red específica.
  /// Esta será la función clave para "traducir" lo que encontramos en las wallets.
  static Future<TokenInfo?> findTokenByContractAddress(String platform, String contractAddress) async {
    // Firestore no es ideal para este tipo de consultas, pero para nuestro caso de uso es suficiente.
    final querySnapshot = await _tokensCollection
        .where('platforms.$platform', isEqualTo: contractAddress)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      print('[Encyclopedia] Token encontrado en caché por contrato: ${doc['symbol']}');
      return TokenInfo.fromFirestore(doc.data() as Map<String, dynamic>);
    }
    
    print('[Encyclopedia] Contrato $contractAddress en $platform no encontrado en caché.');
    return null; // Devuelve null si no lo hemos visto antes.
  }
}