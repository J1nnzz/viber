/// Implementación vacía para plataformas nativas (iOS, Android, desktop).
/// Todos los métodos son no-op; los flags se mantienen por coherencia con la
/// versión web para que Settings pueda leerlos sin condiciones de plataforma.
class NotificationService {
  // ── Flags globales ─────────────────────────────────────────────────────────
  static bool mentionSoundEnabled      = true;
  static bool notificationSoundEnabled = true;

  // ── API pública ────────────────────────────────────────────────────────────

  static void loadPreferences() {}

  /// Sonido de mención (@usuario). Tono doble ascendente.
  static void playMentionSound() {}

  /// Sonido de notificación (solicitud de amistad, invitación a sala).
  static void playNotificationSound() {}

  /// Actualiza el título del documento con el contador de no-leídos.
  static void updateTabTitle(int unread) {}
}
