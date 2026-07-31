import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/skeletons.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../infrastructure/chat_service.dart';
import '../infrastructure/chat_websocket_service.dart';
import '../domain/chat_message.dart';
import '../../auth/infrastructure/auth_service.dart';
import '../../social/presentation/profile_screen.dart';
import '../../quiz/presentation/quiz_challenge.dart';
import '../../quiz/presentation/widgets/quiz_challenge_card.dart';
import '../../quiz/presentation/widgets/quiz_result_card.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/mention_text.dart';

/// Chat privado entre dos amigos.
///
/// Carga los últimos mensajes al abrirse y actualiza el indicador de "visto"
/// (otherReadAt) para mostrar si el otro usuario ha leído los mensajes.
/// El polling es manual (al entrar), no usa WebSocket para DMs.
class DirectChatScreen extends StatefulWidget {
  final String  otherUsername;
  final String? otherDisplayName;
  final String? otherAvatarUrl;

  const DirectChatScreen({
    super.key,
    required this.otherUsername,
    this.otherDisplayName,
    this.otherAvatarUrl,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  final _inputCtrl   = TextEditingController();
  final _scrollCtrl  = ScrollController();

  List<ChatMessage> _messages    = [];
  String? _myUsername;
  int     _otherReadAt = 0;
  bool _loading = true;
  Timer? _pollTimer;
  ChatWebSocketService? _ws;

  int  _firstNewIndex = -1;
  bool _firstLoadDone = false;

  String get _displayName =>
      widget.otherDisplayName?.isNotEmpty == true
          ? widget.otherDisplayName!
          : widget.otherUsername;

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
    await _loadMessages();
    if (token != null && mounted) {
      _ws = ChatWebSocketService(token: token)
        ..onDirectMessage = _onDirectMessage
        ..connect();
    }
    // Poll lento: refresca los "visto" (otherReadAt) y sirve de red de seguridad
    // si el WebSocket se cae. La entrega instantánea la hace el WebSocket.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadMessages(silent: true),
    );
  }

  /// DM recibido en vivo por WebSocket (incluido el eco del propio envío).
  void _onDirectMessage(ChatMessage msg, String from, String to) {
    if (!mounted) return;
    final inConvo = (from == widget.otherUsername && to == _myUsername) ||
        (from == _myUsername && to == widget.otherUsername);
    if (!inConvo) return;
    final dup = _messages.any((m) =>
        m.timestamp == msg.timestamp &&
        m.sender == msg.sender &&
        m.text == msg.text);
    if (dup) return;
    setState(() => _messages.add(msg));
    // Lo envía el otro y tengo el chat abierto → leído.
    if (from == widget.otherUsername) {
      ChatService.markRead(widget.otherUsername, msg.timestamp);
    }
    _scrollToBottom();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final result = await _chatService.getDMs(widget.otherUsername);
      if (!mounted) return;
      final msgs = result.messages;
      final prev = _messages.length;

      if (!_firstLoadDone && msgs.isNotEmpty) {
        final lastRead = ChatService.lastReadFor(widget.otherUsername);
        final firstNew = lastRead == 0
            ? -1
            : msgs.indexWhere((m) => m.timestamp > lastRead);
        _firstNewIndex = firstNew;
        _firstLoadDone = true;
        ChatService.markRead(widget.otherUsername, msgs.last.timestamp);
      } else if (_firstLoadDone && msgs.isNotEmpty) {
        ChatService.markRead(widget.otherUsername, msgs.last.timestamp);
      }

      setState(() {
        _messages    = msgs;
        _otherReadAt = result.otherReadAt;
        _loading     = false;
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
    // Vía WebSocket (instantáneo); el servidor hace eco y se añade al recibirlo.
    if (_ws != null && _ws!.isConnected) {
      _ws!.sendDM(widget.otherUsername, text);
      return;
    }
    // Fallback REST si el WebSocket no está disponible.
    try {
      await _chatService.sendDM(widget.otherUsername, text);
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
    _pollTimer?.cancel();
    _ws?.disconnect();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasSeparator = _firstNewIndex >= 0;
    final itemCount    = _messages.length + (hasSeparator ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            fadeThroughRoute(ProfileScreen(username: widget.otherUsername)),
          ),
          child: Row(
            children: [
              UserAvatar(
                username:  widget.otherUsername,
                avatarUrl: widget.otherAvatarUrl,
                radius:    18,
              ),
              const SizedBox(width: spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '@${widget.otherUsername}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_esports_outlined),
            tooltip: 'chat.quiz_duel_invite'.tr(),
            onPressed: () => startQuizChallenge(
              context, scope: 'DM', otherUsername: widget.otherUsername),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const SkeletonChat()
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: spacingMd, vertical: spacingMd),
                        itemCount: itemCount,
                        itemBuilder: (_, i) {
                          if (hasSeparator && i == _firstNewIndex) {
                            return _buildNewSeparator(
                                _messages.length - _firstNewIndex);
                          }
                          final msgIndex = hasSeparator && i > _firstNewIndex
                              ? i - 1
                              : i;
                          return _buildBubble(_messages[msgIndex]);
                        },
                      ),
          ),
          ChatInputBar(controller: _inputCtrl, onSend: _send),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              username:  widget.otherUsername,
              avatarUrl: widget.otherAvatarUrl,
              radius:    32,
            ),
            const SizedBox(height: spacingLg),
            Text(
              'chat.start_conversation'.tr(namedArgs: {'user': _displayName}),
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
    );
  }

  // ── New messages separator ─────────────────────────────────────────────────

  Widget _buildNewSeparator(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: appDivider, thickness: 0.5)),
          const SizedBox(width: spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: appAccentDim,
              borderRadius: BorderRadius.circular(radiusFull),
              border: Border.all(
                  color: appAccent.withValues(alpha: 0.25), width: 0.5),
            ),
            child: Text(
              'chat.new_messages'.plural(count),
              style: const TextStyle(
                color: appAccent, fontSize: 11, fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: spacingSm),
          Expanded(
              child: Divider(
                  color: appDivider, thickness: 0.5)),
        ],
      ),
    );
  }

  // ── Chat bubble ────────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.sender == _myUsername;

    if (msg.isChallenge) {
      return AppEntrance(
        offsetY: 8,
        child: QuizChallengeCard(
          matchId:     msg.matchId!,
          mode:        msg.mode,
          totalRounds: msg.totalRounds,
          fromLabel:   _displayName,
          isMine:      isMe,
        ),
      );
    }
    if (msg.isResult) {
      return AppEntrance(
        offsetY: 8,
        child: QuizResultCard(
          winner:     msg.winner,
          standings:  msg.standings,
          myUsername: _myUsername,
        ),
      );
    }

    return AppEntrance(
      offsetY: 8,
      duration: const Duration(milliseconds: 280),
      child: Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 4,
          left:  isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? appPurple : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe
              ? null
              : Border.all(color: appDivider),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                  ? Colors.white.withValues(alpha: 0.9)
                  : appAccent,
              onDarkBg: isMe,
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.timeLabel,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.55)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  _buildTick(msg.timestamp),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Tick de estado ─────────────────────────────────────────────────────────

  Widget _buildTick(int msgTimestamp) {
    final isRead = _otherReadAt >= msgTimestamp && _otherReadAt > 0;
    if (isRead) {
      return Icon(Icons.done_all_rounded,
          size: 13, color: Colors.white.withValues(alpha: 0.9));
    }
    return Icon(Icons.done_rounded,
        size: 13, color: Colors.white.withValues(alpha: 0.55));
  }
}
