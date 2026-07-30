/// Mensaje de chat individual (DM o global).
/// El [timestamp] es epoch en milisegundos; [timeLabel] lo formatea como HH:mm.
/// Si [type] == 'QUIZ_CHALLENGE' es un reto de quiz (lleva matchId/mode/totalRounds)
/// y el cliente lo pinta como tarjeta con botón "Unirse".
class ChatMessage {
  final String  sender;
  final String  text;
  final int     timestamp;
  final String? type;
  final int?    matchId;
  final String? mode;
  final int?    totalRounds;
  final String? winner;
  final List<dynamic>? standings;

  const ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.type,
    this.matchId,
    this.mode,
    this.totalRounds,
    this.winner,
    this.standings,
  });

  bool get isChallenge => type == 'QUIZ_CHALLENGE' && matchId != null;
  bool get isResult    => type == 'QUIZ_RESULT';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        sender:      j['sender']    as String? ?? '',
        text:        j['text']      as String? ?? '',
        timestamp:   (j['timestamp'] as num?)?.toInt() ?? 0,
        type:        j['type']        as String?,
        matchId:     (j['matchId']    as num?)?.toInt(),
        mode:        j['mode']        as String?,
        totalRounds: (j['totalRounds'] as num?)?.toInt(),
        winner:      j['winner']      as String?,
        standings:   j['standings']   as List<dynamic>?,
      );

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  String get timeLabel {
    final dt = dateTime;
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class DmResult {
  final List<ChatMessage> messages;
  final int otherReadAt;

  const DmResult({required this.messages, required this.otherReadAt});
}

class Conversation {
  final String  otherUser;
  final String? lastMessage;
  final String? lastSender;
  final int?    lastTimestamp;

  const Conversation({
    required this.otherUser,
    this.lastMessage,
    this.lastSender,
    this.lastTimestamp,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        otherUser:     j['otherUser']    as String? ?? '',
        lastMessage:   j['lastMessage']  as String?,
        lastSender:    j['lastSender']   as String?,
        lastTimestamp: (j['lastTimestamp'] as num?)?.toInt(),
      );
}
