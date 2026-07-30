import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/skeletons.dart';
import '../../auth/infrastructure/auth_service.dart';
import '../../chat/presentation/widgets/chat_input_bar.dart';
import '../../chat/presentation/widgets/mention_text.dart';
import '../../quiz/presentation/quiz_challenge.dart';
import '../../quiz/presentation/widgets/quiz_challenge_card.dart';
import '../../quiz/presentation/widgets/quiz_result_card.dart';
import '../domain/group_models.dart';
import '../infrastructure/group_service.dart';
import '../infrastructure/group_websocket_service.dart';
import 'group_avatar.dart';
import 'group_info_screen.dart';

/// Chat de un grupo. Entrega en vivo por la cola personal `/user/queue/group`
/// (filtrada por groupId); el envío es REST y el servidor hace eco a todos.
class GroupChatScreen extends StatefulWidget {
  final GroupModel group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _service   = GroupService();
  final _auth      = AuthService();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  late GroupModel _group;
  List<GroupMessage> _messages = [];
  String? _myUsername;
  bool _loading = true;
  Timer? _pollTimer;
  GroupWebSocketService? _ws;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _init();
  }

  Future<void> _init() async {
    final token = await _auth.getToken();
    if (token != null) {
      final parts   = token.split('.');
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      _myUsername   = (jsonDecode(decoded) as Map<String, dynamic>)['sub'] as String?;
    }
    await _loadMessages();
    // Refresca rol/permisos por si cambiaron desde el listado
    _service.getGroup(_group.id).then((g) {
      if (mounted) setState(() => _group = g);
    }).catchError((_) {});

    if (token != null && mounted) {
      _ws = GroupWebSocketService(token: token)
        ..onGroupMessage = _onGroupMessage
        ..onKicked = _onKicked
        ..connect();
    }
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10), (_) => _loadMessages(silent: true));
  }

  void _onGroupMessage(int groupId, GroupMessage msg) {
    if (!mounted || groupId != _group.id) return;
    final dup = _messages.any((m) =>
        m.timestamp == msg.timestamp && m.sender == msg.sender && m.text == msg.text);
    if (dup) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _onKicked(int groupId, String groupName) {
    if (!mounted || groupId != _group.id) return;
    Navigator.pop(context, 'kicked');
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final msgs = await _service.getMessages(_group.id);
      if (!mounted) return;
      final prev = _messages.length;
      setState(() { _messages = msgs; _loading = false; });
      if (msgs.length > prev) _scrollToBottom();
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    try {
      await _service.sendMessage(_group.id, text);
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, e.toString().replaceAll('Exception: ', ''), error: true);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _openInfo() async {
    final result = await Navigator.push(
      context, fadeThroughRoute(GroupInfoScreen(groupId: _group.id)));
    if (result == 'left' || result == 'deleted') {
      if (mounted) Navigator.pop(context, result);
    } else if (result is GroupModel && mounted) {
      setState(() => _group = result);
    }
  }

  Future<void> _challenge() async {
    await startQuizChallenge(context, scope: 'GROUP', groupId: _group.id);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ws?.disconnect();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canQuiz = _group.can(_group.startQuizPolicy);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openInfo,
          child: Row(
            children: [
              GroupAvatar(name: _group.name, photoUrl: _group.photoUrl, radius: 18),
              const SizedBox(width: spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_group.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('${_group.memberCount} miembros',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (canQuiz)
            IconButton(
              icon: const Icon(Icons.sports_esports_outlined),
              tooltip: 'Reto de quiz',
              onPressed: _challenge,
            ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Info del grupo',
            onPressed: _openInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const SkeletonChat()
                : _messages.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: spacingMd, vertical: spacingMd),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildItem(_messages[i]),
                      ),
          ),
          ChatInputBar(controller: _inputCtrl, onSend: _send),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GroupAvatar(name: _group.name, photoUrl: _group.photoUrl, radius: 32),
            const SizedBox(height: spacingLg),
            Text('¡Saluda al grupo\n${_group.name}!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14, height: 1.55)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(GroupMessage msg) {
    if (msg.isChallenge) {
      return AppEntrance(
        offsetY: 8,
        child: QuizChallengeCard(
          matchId:     msg.matchId!,
          mode:        msg.mode,
          totalRounds: msg.totalRounds,
          fromLabel:   '@${msg.sender}',
          isMine:      msg.sender == _myUsername,
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
    if (msg.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: appAccentDim,
              borderRadius: BorderRadius.circular(radiusFull),
            ),
            child: Text(msg.text,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11.5, fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    final isMe = msg.sender == _myUsername;
    return AppEntrance(
      offsetY: 8,
      duration: const Duration(milliseconds: 260),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(bottom: 4, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isMe ? appPurple : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: isMe ? null : Border.all(color: appDivider),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('@${msg.sender}',
                      style: const TextStyle(
                          color: appAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              MentionText(
                text: msg.text,
                myUsername: _myUsername,
                baseStyle: TextStyle(
                  color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  fontSize: 14, height: 1.4,
                ),
                accentColor: isMe ? Colors.white.withValues(alpha: 0.9) : appAccent,
                onDarkBg: isMe,
              ),
              const SizedBox(height: 3),
              Text(msg.timeLabel,
                  style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.55)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
