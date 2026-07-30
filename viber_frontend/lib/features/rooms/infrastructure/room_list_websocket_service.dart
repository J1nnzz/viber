import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:viber/core/constants/api_constants.dart';
import '../domain/room.dart';

/// Servicio que mantiene una suscripción a /topic/rooms.
/// El backend emite un evento cada vez que se crea, edita o cierra una sala,
/// eliminando la necesidad de polling frecuente.
class RoomListWebSocketService {
  StompClient? _client;
  final String token;

  Function(Room)?  onRoomCreated;
  Function(Room)?  onRoomUpdated;
  Function(int)?   onRoomClosed; // roomId

  RoomListWebSocketService({required this.token});

  void connect() {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: ApiConstants.wsUrl,
        stompConnectHeaders:     {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: _onConnect,
        onStompError: (_) {},
        onDisconnect: (_) {},
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _client!.subscribe(
      destination: '/topic/rooms',
      callback: (frame) {
        if (frame.body == null) return;
        try {
          final json = jsonDecode(frame.body!) as Map<String, dynamic>;
          final type = json['type'] as String?;
          switch (type) {
            case 'ROOM_CREATED':
              final room = Room.fromJson(json['room'] as Map<String, dynamic>);
              onRoomCreated?.call(room);
            case 'ROOM_UPDATED':
              final room = Room.fromJson(json['room'] as Map<String, dynamic>);
              onRoomUpdated?.call(room);
            case 'ROOM_CLOSED':
              final roomId = (json['roomId'] as num?)?.toInt();
              if (roomId != null) onRoomClosed?.call(roomId);
          }
        } catch (_) {}
      },
    );
  }

  void disconnect() => _client?.deactivate();
}
