import 'package:flutter/foundation.dart' show kIsWeb;

/// Constantes de URL para todos los servicios de la API REST y el WebSocket.
/// En web usa localhost (misma máquina). En móvil usa la IP de red local.
class ApiConstants {
  ApiConstants._();

  // ── IP de red local del PC donde corre el backend ─────────────────────
  static const String _mobileHost = 'http://10.57.14.114:8080';
  static const String _webHost    = 'http://localhost:8080';

  static String get _host => kIsWeb ? _webHost : _mobileHost;

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