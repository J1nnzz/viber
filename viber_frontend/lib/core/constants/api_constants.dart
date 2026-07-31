import 'package:flutter/foundation.dart' show kIsWeb;

/// Constantes de URL para todos los servicios de la API REST y el WebSocket.
///
/// El host del backend se elige así:
///  1. Si se define `VIBER_API_HOST` al compilar, manda esa.
///  2. Si no, en web se usa localhost (el navegador corre en la misma máquina).
///  3. Si no, en móvil se usa 10.0.2.2, que es el alias del emulador de Android
///     para el localhost del PC anfitrión.
///
/// En un dispositivo físico el paso 3 no sirve (el teléfono no comparte
/// localhost con el PC), así que hay que pasar la IP del PC en la red local:
///
/// ```
/// flutter run                --dart-define=VIBER_API_HOST=http://192.168.1.42:8080
/// flutter build apk --release --dart-define=VIBER_API_HOST=http://192.168.1.42:8080
/// ```
///
/// Esa IP suele venir por DHCP y cambia al reconectar o al cambiar de red;
/// consúltala con `ipconfig` (Windows) o `ip addr` (Linux) antes de compilar.
class ApiConstants {
  ApiConstants._();

  /// Host indicado a mano al compilar. Vacío = usar los valores por defecto.
  static const String _hostOverride = String.fromEnvironment('VIBER_API_HOST');

  static const String _webHost    = 'http://localhost:8080';
  static const String _mobileHost = 'http://10.0.2.2:8080';

  static String get _host => _hostOverride.isNotEmpty
      ? _hostOverride
      : (kIsWeb ? _webHost : _mobileHost);

  static String get baseUrl => '$_host/api';
  static String get wsUrl   => '$_host/ws';

  // ── Endpoints por dominio ──────────────────────────────────────────────
  static String get authUrl    => '$baseUrl/auth';
  static String get roomsUrl   => '$baseUrl/rooms';
  static String get userUrl    => '$baseUrl/user';
  static String get youtubeUrl => '$baseUrl/youtube';
  static String get chatUrl    => '$baseUrl/chat';
  static String get quizUrl    => '$baseUrl/quiz';
  static String get groupsUrl  => '$baseUrl/groups';
  static String get pushUrl    => '$baseUrl/push';
}