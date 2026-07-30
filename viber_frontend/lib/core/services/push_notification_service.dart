import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:viber/core/constants/api_constants.dart';
import 'package:viber/core/services/base_api_service.dart';

/// Handler de mensajes recibidos con la app en segundo plano o cerrada.
/// Debe ser una función top-level anotada con `@pragma('vm:entry-point')`.
/// No necesita lógica: con un payload `notification`, Android/iOS muestran la
/// notificación en la bandeja del sistema automáticamente.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Cliente REST para registrar/eliminar el token FCM en el backend.
class _PushApi extends BaseApiService {
  Future<void> register(String token, String platform) async {
    await http.post(
      Uri.parse('${ApiConstants.pushUrl}/register'),
      headers: await authHeaders(),
      body: jsonEncode({'token': token, 'platform': platform}),
    );
  }

  Future<void> unregister(String token) async {
    await http.post(
      Uri.parse('${ApiConstants.pushUrl}/unregister'),
      headers: await authHeaders(),
      body: jsonEncode({'token': token}),
    );
  }
}

/// Notificaciones push para móvil mediante Firebase Cloud Messaging.
///
/// En web y escritorio no hace nada (allí se usan las notificaciones web del
/// [NotificationService]). El flujo es:
///   1. [initFirebase] en `main()` (inicializa Firebase + handler de fondo).
///   2. [registerForUser] tras iniciar sesión (pide permiso, obtiene token y
///      lo registra en el backend).
///   3. [unregister] al cerrar sesión.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final _api = _PushApi();
  GlobalKey<ScaffoldMessengerState>? _messengerKey;
  String? _token;
  bool _firebaseReady = false;
  bool _foregroundListenerSet = false;

  /// Solo en Android/iOS. En el resto de plataformas todo es no-op.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Inicializa Firebase y registra el handler de segundo plano.
  /// Seguro de llamar en cualquier plataforma (no hace nada si no aplica).
  Future<void> initFirebase() async {
    if (!_supported) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Push: no se pudo inicializar Firebase: $e');
    }
  }

  /// Guarda la key del ScaffoldMessenger global para mostrar avisos cuando llega
  /// una notificación con la app en primer plano.
  void attachMessenger(GlobalKey<ScaffoldMessengerState> key) {
    _messengerKey = key;
  }

  /// Pide permiso de notificaciones, obtiene el token FCM y lo registra en el
  /// backend. Llamar tras iniciar sesión.
  Future<void> registerForUser() async {
    if (!_supported || !_firebaseReady) return;
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      if (!_foregroundListenerSet) {
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        _foregroundListenerSet = true;
      }

      final token = await messaging.getToken();
      if (token == null) return;
      _token = token;
      await _api.register(token, _platform);

      messaging.onTokenRefresh.listen((t) async {
        _token = t;
        try {
          await _api.register(t, _platform);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('Push: error registrando token: $e');
    }
  }

  /// Da de baja el token en el backend y lo borra del dispositivo (al cerrar sesión).
  Future<void> unregister() async {
    if (!_supported) return;
    try {
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token != null) await _api.unregister(token);
      await FirebaseMessaging.instance.deleteToken();
      _token = null;
    } catch (e) {
      debugPrint('Push: error dando de baja token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final messenger = _messengerKey?.currentState;
    if (messenger == null) return;

    final text = [n.title, n.body]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    if (text.isEmpty) return;

    messenger.showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }
}
