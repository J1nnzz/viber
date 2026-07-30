import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:viber/core/constants/api_constants.dart';
import '../domain/chat_message.dart';

/// Conexión STOMP/SockJS para el chat en tiempo real (global y DMs).
///
/// Se suscribe a:
///  - `/topic/chat.global` — mensajes del chat global (broadcast)
///  - `/user/queue/dm`     — mensajes directos dirigidos a este usuario
///
/// El JWT viaja en las cabeceras del frame CONNECT para autenticar la sesión.
/// Cada pantalla crea su instancia, registra los callbacks que necesita y la
/// desactiva en dispose.
class ChatWebSocketService {
  StompClient? _client;
  final String token;

  /// Mensaje nuevo en el chat global.
  void Function(ChatMessage message)? onGlobalMessage;

  /// DM entrante o eco propio. [from] = remitente, [to] = destinatario;
  /// la pantalla decide si pertenece a la conversación abierta.
  void Function(ChatMessage message, String from, String to)? onDirectMessage;

  void Function()? onConnected;
  void Function()? onDisconnected;

  ChatWebSocketService({required this.token});

  // ── Conexión ──────────────────────────────────────────────────────────────

  void connect() {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: ApiConstants.wsUrl,
        onConnect: _onConnect,
        onDisconnect: (_) => onDisconnected?.call(),
        onStompError: (frame) =>
            // ignore: avoid_print
            print('Chat STOMP error: ${frame.body}'),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _client!.subscribe(
      destination: '/topic/chat.global',
      callback: (f) {
        if (f.body == null) return;
        onGlobalMessage?.call(
            ChatMessage.fromJson(jsonDecode(f.body!) as Map<String, dynamic>));
      },
    );

    _client!.subscribe(
      destination: '/user/queue/dm',
      callback: (f) {
        if (f.body == null) return;
        final j = jsonDecode(f.body!) as Map<String, dynamic>;
        onDirectMessage?.call(
          ChatMessage.fromJson(j),
          j['sender'] as String? ?? '',
          j['to'] as String? ?? '',
        );
      },
    );

    onConnected?.call();
  }

  // ── Envío ─────────────────────────────────────────────────────────────────

  void sendGlobal(String text) {
    _client?.send(
      destination: '/app/chat.global',
      body: jsonEncode({'text': text}),
    );
  }

  void sendDM(String to, String text) {
    _client?.send(
      destination: '/app/chat.dm',
      body: jsonEncode({'to': to, 'text': text}),
    );
  }

  bool get isConnected => _client?.connected ?? false;

  void disconnect() => _client?.deactivate();
}
