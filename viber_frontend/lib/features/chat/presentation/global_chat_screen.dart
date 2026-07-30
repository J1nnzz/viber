import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:viber/core/services/notification_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/skeletons.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../infrastructure/chat_service.dart';
import '../infrastructure/chat_websocket_service.dart';
import '../domain/chat_message.dart';
import '../../auth/infrastructure/auth_service.dart';
import '../../social/presentation/widgets/user_profile_sheet.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/mention_text.dart';

/// Chat global de la plataforma: todos los usuarios autenticados pueden participar.
/// Hace polling automático de mensajes nuevos cada 8 segundos.
class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});

  @override
  State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  final _inputCtrl   = TextEditingController();
  final _scrollCtrl  = ScrollController();

  List<ChatMessage> _messages = [];
  String? _myUsername;
  bool _loading = true;
  ChatWebSocketService? _ws;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final token = await _authService.getToken();
    if (token != null) {
      final parts   = token.split('.');
      final decoded = utf8.decode(
          base64Url.decode(base64Url.normalize(parts[1])));
      final payload = jsonDecode(decoded) as Map<String, dynamic>;
      _myUsername   = payload['sub'] as String?;
    }
    // Historial inicial por REST; a partir de ahí, todo en vivo por WebSocket.
    await _loadMessages();
    if (token != null && mounted) {
      _ws = ChatWebSocketService(token: token)
        ..onGlobalMessage = _onGlobalMessage
        ..connect();
    }
  }

  /// Mensaje nuevo recibido en vivo por WebSocket (incluido el propio, que el
  /// servidor reenvía al hacer broadcast en /topic/chat.global).
  void _onGlobalMessage(ChatMessage msg) {
    if (!mounted) return;
    final dup = _messages.any((m) =>
        m.timestamp == msg.timestamp &&
        m.sender == msg.sender &&
        m.text == msg.text);
    if (dup) return;
    setState(() => _messages.add(msg));
    if (_myUsername != null && msg.sender != _myUsername) {
      final pattern =
          RegExp('@${RegExp.escape(_myUsername!)}\\b', caseSensitive: false);
      if (pattern.hasMatch(msg.text)) NotificationService.playMentionSound();
    }
    _scrollToBottom();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await _chatService.getGlobalMessages();
      if (!mounted) return;
      final prev = _messages.length;
      setState(() {
        _messages = msgs;
        _loading  = false;
      });
      if (msgs.length > prev) _scrollToBottom();
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    // Vía WebSocket (instantáneo); el mensaje vuelve por el broadcast y se añade.
    if (_ws != null && _ws!.isConnected) {
      _ws!.sendGlobal(text);
      return;
    }
    // Fallback REST si el WebSocket no está disponible.
    try {
      await _chatService.sendGlobal(text);
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context,
            e.toString().replaceAll('Exception: ', ''),
            error: true);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ws?.disconnect();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: appAccentGlow,
                borderRadius: BorderRadius.circular(radiusSm),
                border: Border.all(color: appDivider),
              ),
              child: const Icon(Icons.public_rounded,
                  color: appAccent, size: 19),
            ),
            const SizedBox(width: spacingSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chat Global',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Toda la comunidad Viber',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const SkeletonChat()
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(spacingXl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public_rounded,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                  size: 40),
                              const SizedBox(height: spacingMd),
                              Text(
                                'Sé el primero en escribir\nen el chat global.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 14,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: spacingMd, vertical: spacingMd),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildBubble(_messages[i]),
                      ),
          ),
          ChatInputBar(controller: _inputCtrl, onSend: _send),
        ],
      ),
    );
  }

  // ── Bubble ─────────────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.sender == _myUsername;

    return AppEntrance(
      offsetY: 8,
      duration: const Duration(milliseconds: 280),
      child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => showUserProfileSheet(
                context,
                username:   msg.sender,
                myUsername: _myUsername ?? '',
              ),
              child: UserAvatar(username: msg.sender, radius: 14),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: GestureDetector(
                      onTap: () => showUserProfileSheet(
                        context,
                        username:   msg.sender,
                        myUsername: _myUsername ?? '',
                      ),
                      child: Text(
                        msg.sender,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isMe
                        ? appPurple
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    border: isMe
                        ? null
                        : Border.all(
                            color: appDivider),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      MentionText(
                        text:        msg.text,
                        myUsername:  _myUsername,
                        baseStyle:   TextStyle(
                          color: isMe
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        accentColor: isMe
                            ? Colors.white.withOpacity(0.9)
                            : appAccent,
                        onDarkBg: isMe,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        msg.timeLabel,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.55)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
      ),
    );
  }
}
