import 'ad_service_stub.dart'
    if (dart.library.io) 'ad_service_mobile.dart';

/// Capa de anuncios con una sola interfaz y dos implementaciones elegidas en
/// compilación (igual que el resto de servicios con split por plataforma del
/// proyecto):
///   · móvil (Android/iOS) → AdMob vía google_mobile_ads (ad_service_mobile.dart)
///   · web / escritorio    → no-op                       (ad_service_stub.dart)
///
/// Decisión de proyecto: los anuncios van SOLO en móvil. En web la monetización
/// es Ko-fi (ver settings) — aquí no se sirve ningún anuncio. La UI llama
/// siempre a `AdService.instance.showRewarded()` sin saber en qué plataforma está.
abstract class AdService {
  /// Inicializa el SDK de anuncios. Idempotente. No-op fuera de Android/iOS.
  Future<void> initialize();

  /// Muestra un anuncio recompensado y devuelve `true` solo si el usuario lo
  /// completó y se ganó la recompensa. Fuera de móvil devuelve `false` sin más.
  Future<bool> showRewarded();

  /// Instancia única, resuelta según la plataforma de compilación.
  static final AdService instance = createAdService();
}
