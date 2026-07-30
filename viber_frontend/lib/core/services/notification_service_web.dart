// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

/// Servicio de notificaciones para Flutter Web.
///
/// • Sonidos  → Web Audio API (sin assets externos, sin paquetes extra)
/// • Tab title → document.title
///
/// Los browsers exigen un gesto de usuario previo antes de permitir audio.
/// Si el contexto no está desbloqueado el primer sonido se descarta
/// silenciosamente; a partir del segundo gesto ya funciona.
class NotificationService {
  // ── Claves de persistencia ─────────────────────────────────────────────────
  static const _kMention = 'viber_mention_sound';
  static const _kNotif   = 'viber_notif_sound';

  // ── Flags con persistencia en localStorage ─────────────────────────────────

  static bool _mentionSoundEnabled = true;
  static bool _notifSoundEnabled   = true;

  /// Inicializa los flags leyendo los valores guardados en localStorage.
  /// Llamar una vez al arrancar la app (antes de mostrar Settings).
  static void loadPreferences() {
    try {
      final s = html.window.localStorage;
      if (s.containsKey(_kMention)) {
        _mentionSoundEnabled = s[_kMention] != 'false';
      }
      if (s.containsKey(_kNotif)) {
        _notifSoundEnabled = s[_kNotif] != 'false';
      }
    } catch (_) {}
  }

  static bool get mentionSoundEnabled => _mentionSoundEnabled;
  static set mentionSoundEnabled(bool v) {
    _mentionSoundEnabled = v;
    try { html.window.localStorage[_kMention] = v.toString(); } catch (_) {}
  }

  static bool get notificationSoundEnabled => _notifSoundEnabled;
  static set notificationSoundEnabled(bool v) {
    _notifSoundEnabled = v;
    try { html.window.localStorage[_kNotif] = v.toString(); } catch (_) {}
  }

  // ── Título de pestaña ──────────────────────────────────────────────────────

  static String _baseTitle = 'Viber';

  /// Pone "(N) Viber" en la pestaña cuando [unread] > 0.
  static void updateTabTitle(int unread) {
    try {
      html.document.title = unread > 0 ? '($unread) $_baseTitle' : _baseTitle;
    } catch (_) {}
  }

  // ── Sonidos ────────────────────────────────────────────────────────────────

  /// Tono doble ascendente para menciones (@usuario).
  static void playMentionSound() {
    if (!_mentionSoundEnabled) return;
    _beep(freq: 880, duration: 0.12, gain: 0.22);
    Timer(
      const Duration(milliseconds: 145),
      () => _beep(freq: 1200, duration: 0.14, gain: 0.18),
    );
  }

  /// Tono suave único para notificaciones (solicitud de amistad, invitación).
  static void playNotificationSound() {
    if (!_notifSoundEnabled) return;
    _beep(freq: 600, duration: 0.22, gain: 0.16);
    Timer(
      const Duration(milliseconds: 250),
      () => _beep(freq: 750, duration: 0.18, gain: 0.12),
    );
  }

  // ── Internos ───────────────────────────────────────────────────────────────

  static void _beep({
    required double freq,
    required double duration,
    required double gain,
  }) {
    try {
      // Usamos js.context.callMethod para no depender de AudioContext en dart:html
      // (su API es verbosa). Un eval() es más limpio y no requiere paquetes extra.
      js.context.callMethod('eval', [
        '(function(){'
            'try{'
            'var c=new(window.AudioContext||window.webkitAudioContext)();'
            'var o=c.createOscillator(),g=c.createGain();'
            'o.connect(g);g.connect(c.destination);'
            'o.frequency.value=$freq;'
            "o.type='sine';"
            'g.gain.setValueAtTime($gain,c.currentTime);'
            'g.gain.exponentialRampToValueAtTime(0.0001,c.currentTime+$duration);'
            'o.start(c.currentTime);'
            'o.stop(c.currentTime+$duration);'
            '}catch(e){}'
            '})();',
      ]);
    } catch (_) {}
  }
}
