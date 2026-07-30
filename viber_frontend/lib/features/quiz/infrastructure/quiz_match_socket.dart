import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:viber/core/constants/api_constants.dart';
import '../domain/match_models.dart';

/// Escucha las invitaciones a partidas de quiz por la cola personal
/// `/user/queue/quizmatch`. Vive en HomeScreen mientras la sesión está abierta.
class QuizInviteSocket {
  StompClient? _client;
  final String token;
  void Function(MatchInvite invite)? onInvite;

  QuizInviteSocket({required this.token});

  void connect() {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: ApiConstants.wsUrl,
        onConnect: (_) => _client!.subscribe(
          destination: '/user/queue/quizmatch',
          callback: (f) {
            if (f.body == null) return;
            final j = jsonDecode(f.body!) as Map<String, dynamic>;
            if (j['type'] == 'INVITE') onInvite?.call(MatchInvite.fromJson(j));
          },
        ),
        onStompError: (frame) =>
            // ignore: avoid_print
            print('Quiz invite STOMP error: ${frame.body}'),
        stompConnectHeaders:    {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _client!.activate();
  }

  void disconnect() => _client?.deactivate();
}

/// Conexión a una partida concreta: difusiones por `/topic/quizmatch.{id}` y
/// envío de eventos a `/app/quizmatch.{id}.{join|leave|start|answer}`.
class QuizMatchSocket {
  StompClient? _client;
  final int    matchId;
  final String token;

  void Function(LobbyState lobby)?      onLobby;
  void Function(QuestionEvent question)? onQuestion;
  void Function(RevealEvent reveal)?     onReveal;
  void Function(FinalEvent result)?      onFinal;
  void Function()? onConnected;

  QuizMatchSocket({required this.matchId, required this.token});

  void connect() {
    _client = StompClient(
      config: StompConfig.sockJS(
        url: ApiConstants.wsUrl,
        onConnect: _onConnect,
        onStompError: (frame) =>
            // ignore: avoid_print
            print('Quiz match STOMP error: ${frame.body}'),
        stompConnectHeaders:    {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _client!.activate();
  }

  void _onConnect(StompFrame frame) {
    _client!.subscribe(
      destination: '/topic/quizmatch.$matchId',
      callback: (f) {
        if (f.body == null) return;
        final j = jsonDecode(f.body!) as Map<String, dynamic>;
        switch (j['type']) {
          case 'LOBBY':    onLobby?.call(LobbyState.fromJson(j));       break;
          case 'QUESTION': onQuestion?.call(QuestionEvent.fromJson(j)); break;
          case 'REVEAL':   onReveal?.call(RevealEvent.fromJson(j));     break;
          case 'FINAL':    onFinal?.call(FinalEvent.fromJson(j));       break;
        }
      },
    );
    onConnected?.call();
  }

  void _send(String suffix, [Map<String, dynamic>? body]) {
    _client?.send(
      destination: '/app/quizmatch.$matchId.$suffix',
      body: jsonEncode(body ?? const {}),
    );
  }

  void join()  => _send('join');
  void leave() => _send('leave');
  void start() => _send('start');
  void answer(int optionId) => _send('answer', {'optionId': optionId});

  bool get isConnected => _client?.connected ?? false;

  void disconnect() => _client?.deactivate();
}
