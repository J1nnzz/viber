import 'dart:convert';
import 'package:viber/core/constants/api_constants.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../rooms/domain/room_message.dart';

/// Gestiona la conexión STOMP/SockJS con el servidor para una sala concreta.
///
/// Al conectar se suscribe a tres canales:
///  1. /topic/room.{roomId} — broadcast general de eventos (reproducción, chat, cola, roles)
///  2. /user/queue/kick     — notificación personal de expulsión por el host
///  3. /user/queue/full     — notificación personal de sala llena al intentar entrar
///
/// El JWT se envía en las cabeceras STOMP del frame CONNECT para autenticar la sesión.
class RoomWebSocketService {
  StompClient? _client;

  final int    roomId;
  final String username;
  final String token;

  // ── Callbacks que la UI registra ──────────────────────────────────────────
  /// Mensajes del canal de sala (broadcast a todos)
  Function(RoomMessage)? onMessage;

  /// Notificación personal: este usuario fue expulsado
  Function()? onKicked;

  /// Notificación personal: sala llena, entrada rechazada
  Function()? onRoomFull;

  Function()? onConnected;
  Function()? onDisconnected;

  RoomWebSocketService({
    required this.roomId,
    required this.username,
    required this.token,
  });

  // ── Conexión ──────────────────────────────────────────────────────────────

  void connect() {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: ApiConstants.wsUrl,
        onConnect: _onConnect,
        onDisconnect: (_) => onDisconnected?.call(),
        onStompError: (frame) =>
            // ignore: avoid_print
            print('STOMP error: ${frame.body}'),
        stompConnectHeaders:    {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    // 1. Canal de sala — mensajes para todos los presentes
    _client!.subscribe(
      destination: '/topic/room.$roomId',
      callback: (frame) {
        if (frame.body != null) {
          final msg = RoomMessage.fromJson(jsonDecode(frame.body!));
          onMessage?.call(msg);
        }
      },
    );

    // 2. Canal personal — expulsión por el host
    _client!.subscribe(
      destination: '/user/queue/kick',
      callback: (_) => onKicked?.call(),
    );

    // 3. Canal personal — entrada rechazada por sala llena
    _client!.subscribe(
      destination: '/user/queue/full',
      callback: (_) => onRoomFull?.call(),
    );

    // 4. Notificar entrada a la sala
    sendMessage(RoomMessage(
      type:           RoomMessage.userJoined,
      senderUsername: username,
    ));

    onConnected?.call();
  }

  // ── Envío ─────────────────────────────────────────────────────────────────

  void sendMessage(RoomMessage message) {
    _client?.send(
      destination: '/app/room.$roomId.control',
      body: jsonEncode(message.toJson()),
    );
  }

  // ── Helpers de moderación (solo host los usa) ─────────────────────────────

  void promoteToDJ(String targetUsername) => sendMessage(RoomMessage(
        type:           RoomMessage.roleChange,
        senderUsername: username,
        targetUsername: targetUsername,
        role:           'DJ',
      ));

  void demoteToListener(String targetUsername) => sendMessage(RoomMessage(
        type:           RoomMessage.roleChange,
        senderUsername: username,
        targetUsername: targetUsername,
        role:           'LISTENER',
      ));

  void kickUser(String targetUsername) => sendMessage(RoomMessage(
        type:           RoomMessage.userKicked,
        senderUsername: username,
        targetUsername: targetUsername,
      ));

  void unkickUser(String targetUsername) => sendMessage(RoomMessage(
        type:           RoomMessage.userUnkicked,
        senderUsername: username,
        targetUsername: targetUsername,
      ));

  void muteUser(String targetUsername) => sendMessage(RoomMessage(
        type:           RoomMessage.userMuted,
        senderUsername: username,
        targetUsername: targetUsername,
      ));

  void unmuteUser(String targetUsername) => sendMessage(RoomMessage(
        type:           RoomMessage.userUnmuted,
        senderUsername: username,
        targetUsername: targetUsername,
      ));

  // ── Desconexión ───────────────────────────────────────────────────────────

  void disconnect() {
    sendMessage(RoomMessage(
      type:           RoomMessage.userLeft,
      senderUsername: username,
    ));
    _client?.deactivate();
  }
}