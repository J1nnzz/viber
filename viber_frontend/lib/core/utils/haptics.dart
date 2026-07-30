import 'package:flutter/services.dart';

/// Punto único de feedback háptico de la app.
///
/// Centralizarlo aquí permite, más adelante, respetar un ajuste de usuario o
/// matizar por plataforma sin tocar cada call-site. En web los métodos de
/// `HapticFeedback` simplemente no hacen nada (no-op), así que es seguro llamarlos.
class Haptics {
  Haptics._();

  /// Toque sutil — favoritos, acciones ligeras.
  static void light() => HapticFeedback.lightImpact();

  /// Toque medio — acciones con peso (entrar a una sala).
  static void medium() => HapticFeedback.mediumImpact();

  /// Cambio de selección — pestañas, segmentos.
  static void selection() => HapticFeedback.selectionClick();

  /// Acierto (quiz) — golpe medio satisfactorio.
  static void success() => HapticFeedback.mediumImpact();

  /// Fallo (quiz) — golpe fuerte.
  static void error() => HapticFeedback.heavyImpact();
}
