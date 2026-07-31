import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:viber/core/constants/api_constants.dart';
import '../../../core/services/base_api_service.dart';
import '../domain/chat_message.dart';
import '../domain/chat_repository.dart';

// ── Unread tracking ───────────────────────────────────────────────────────────

class _UnreadTracker {
  static final Map<String, int> _lastRead = {};
  static String? _myUsername;

  static final ValueNotifier<int> unreadNotifier = ValueNotifier(0);

  static void setMyUsername(String username) => _myUsername = username;
  static void markRead(String username, int timestamp) =>
      _lastRead[username] = timestamp;
  static int lastReadFor(String username) => _lastRead[username] ?? 0;

  static bool isUnread(Conversation c) {
    if (_myUsername != null && c.lastSender == _myUsername) return false;
    return (c.lastTimestamp ?? 0) > (_lastRead[c.otherUser] ?? 0);
  }

  static void updateUnread(List<Conversation> conversations) {
    unreadNotifier.value = conversations.where(isUnread).length;
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Cliente HTTP para la API de chat (/api/chat): mensajes directos y chat global.
///
/// Expone también la API estática de "no leídos" (unreadNotifier, markRead, isUnread)
/// que [HomeScreen] usa para mostrar el badge rojo en el tab de mensajes sin
/// necesitar un widget en el árbol.
class ChatService extends BaseApiService implements ChatRepository {

  // ── Unread API (static) ───────────────────────────────────────────────────

  static ValueNotifier<int> get unreadNotifier  => _UnreadTracker.unreadNotifier;
  static void markRead(String username, int ts)  => _UnreadTracker.markRead(username, ts);
  static int  lastReadFor(String username)       => _UnreadTracker.lastReadFor(username);
  static bool isUnread(Conversation conv)        => _UnreadTracker.isUnread(conv);
  static void updateUnread(List<Conversation> c) => _UnreadTracker.updateUnread(c);

  // ── HTTP headers (with unread-tracking side effect) ───────────────────────

  @override
  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (token != null && _UnreadTracker._myUsername == null) {
      try {
        final parts   = token.split('.');
        final decoded = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])));
        final payload = jsonDecode(decoded) as Map<String, dynamic>;
        final sub = payload['sub'] as String?;
        if (sub != null) _UnreadTracker.setMyUsername(sub);
      } catch (_) {}
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Conversaciones ────────────────────────────────────────────────────────

  @override
  Future<List<Conversation>> getConversations() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.chatUrl}/conversations'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => Conversation.fromJson(e))
          .toList();
    }
    throwFromResponse(res, 'errors.conversations_load'.tr());
  }

  // ── Mensajes directos ─────────────────────────────────────────────────────

  @override
  Future<DmResult> getDMs(String username) async {
    final res = await http.get(
      Uri.parse('${ApiConstants.chatUrl}/dm/$username'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      final body     = jsonDecode(res.body) as Map<String, dynamic>;
      final messages = (body['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return DmResult(
        messages:    messages,
        otherReadAt: (body['otherReadAt'] as num?)?.toInt() ?? 0,
      );
    }
    throwFromResponse(res, 'errors.messages_load'.tr());
  }

  @override
  Future<void> sendDM(String username, String text) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.chatUrl}/dm/$username'),
      headers: await authHeaders(),
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.message_send'.tr());
  }

  // ── Chat global ───────────────────────────────────────────────────────────

  @override
  Future<List<ChatMessage>> getGlobalMessages() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.chatUrl}/global'),
      headers: await authHeaders(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => ChatMessage.fromJson(e))
          .toList();
    }
    throwFromResponse(res, 'errors.global_chat_load'.tr());
  }

  @override
  Future<void> sendGlobal(String text) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.chatUrl}/global'),
      headers: await authHeaders(),
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode != 200) throwFromResponse(res, 'errors.message_send'.tr());
  }
}
