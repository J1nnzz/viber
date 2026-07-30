import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:viber/core/constants/api_constants.dart';
import '../domain/group_models.dart';

/// Conexión STOMP/SockJS para los grupos en tiempo real.
///
/// Se suscribe a las colas personales del usuario (no a topics abiertos, para
/// que un no-miembro no pueda espiar un grupo):
///  - `/user/queue/group`      — mensajes de cualquier grupo del usuario
///  - `/user/queue/group-kick` — aviso de expulsión de un grupo
///
/// Cada payload de mensaje incluye `groupId`, así que la pantalla abierta filtra
/// los que le corresponden.
class GroupWebSocketService {
  StompClient? _client;
  final String token;

  /// Mensaje entrante en algún grupo. Incluye el groupId para enrutar.
  void Function(int groupId, GroupMessage message)? onGroupMessage;

  /// Este usuario fue expulsado de un grupo.
  void Function(int groupId, String groupName)? onKicked;

  void Function()? onConnected;

  GroupWebSocketService({required this.token});

  void connect() {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: ApiConstants.wsUrl,
        onConnect: _onConnect,
        onStompError: (frame) =>
            // ignore: avoid_print
            print('Group STOMP error: ${frame.body}'),
        stompConnectHeaders:    {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _client!.subscribe(
      destination: '/user/queue/group',
      callback: (f) {
        if (f.body == null) return;
        final j = jsonDecode(f.body!) as Map<String, dynamic>;
        final groupId = (j['groupId'] as num?)?.toInt();
        if (groupId == null) return;
        onGroupMessage?.call(groupId, GroupMessage.fromJson(j));
      },
    );

    _client!.subscribe(
      destination: '/user/queue/group-kick',
      callback: (f) {
        if (f.body == null) return;
        final j = jsonDecode(f.body!) as Map<String, dynamic>;
        final groupId = (j['groupId'] as num?)?.toInt();
        if (groupId == null) return;
        onKicked?.call(groupId, j['groupName'] as String? ?? '');
      },
    );

    onConnected?.call();
  }

  bool get isConnected => _client?.connected ?? false;

  void disconnect() => _client?.deactivate();
}
