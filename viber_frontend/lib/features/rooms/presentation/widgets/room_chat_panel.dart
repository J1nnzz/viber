import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/motion.dart';
import '../../../rooms/domain/room_state.dart';
import '../../../chat/presentation/widgets/chat_input_bar.dart';
import '../../../chat/presentation/widgets/mention_text.dart';
import '../../../social/presentation/widgets/user_profile_sheet.dart';

/// Panel lateral de chat de una sala.
///
/// Muestra el historial de mensajes con avatares y permite al host/DJ
/// moderar usuarios (silenciar, expulsar, promover a DJ o degradar a oyente)
/// pulsando sobre el avatar de cada participante.
class RoomChatPanel extends StatefulWidget {
  final List<Map<String, String>> messages;
  final List<String> users;
  final String? currentUsername;
  final String  hostUsername;
  final TextEditingController chatController;
  final VoidCallback onSend;

  // ── Nuevos: roles y moderación ────────────────────────────────────────────
  final Map<String, String>  userRoles;
  final Set<String>          mutedUsers;
  final Set<String>          kickedUsers;
  final bool                 isHost;
  final Map<String, String?> userAvatars;
  final void Function(String)? onPromoteDJ;
  final void Function(String)? onDemote;
  final void Function(String)? onKick;
  final void Function(String)? onUnkick;
  final void Function(String)? onMute;
  final void Function(String)? onUnmute;

  const RoomChatPanel({
    super.key,
    required this.messages,
    required this.users,
    required this.currentUsername,
    required this.hostUsername,
    required this.chatController,
    required this.onSend,
    this.userRoles    = const {},
    this.mutedUsers   = const {},
    this.kickedUsers  = const {},
    this.isHost       = false,
    this.userAvatars  = const {},
    this.onPromoteDJ,
    this.onDemote,
    this.onKick,
    this.onUnkick,
    this.onMute,
    this.onUnmute,
  });

  @override
  State<RoomChatPanel> createState() => _RoomChatPanelState();
}

class _RoomChatPanelState extends State<RoomChatPanel> {
  int _tab = 0;
  final ScrollController _scroll = ScrollController();

  // ── Helpers de rol ─────────────────────────────────────────────────────────
  String _roleOf(String username) =>
      widget.userRoles[username] ?? RoomRole.listener;

  bool _isUserHost(String u) => _roleOf(u) == RoomRole.host;
  bool _isUserDJ(String u)   => _roleOf(u) == RoomRole.dj;
  bool _isUserMuted(String u) => widget.mutedUsers.contains(u);

  @override
  void didUpdateWidget(RoomChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── Build principal ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appSurfaceColor,
      child: Column(
        children: [
          _buildTabs(context),
          Expanded(child: _tab == 0 ? _buildChat(context) : _buildUsers(context)),
        ],
      ),
    );
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _buildTabs(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: appDivider)),
      ),
      child: Row(children: [_tab_(context, 0, 'Chat'), _tab_(context, 1, 'room_chat.users_tab'.tr())]),
    );
  }

  Widget _tab_(BuildContext context, int index, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? appAccent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      active ? appAccent : context.appTextSecColor,
              fontSize:   13,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Widget _buildChat(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum_outlined,
                          color: context.appTextSecColor.withOpacity(0.4),
                          size: 30),
                      const SizedBox(height: 8),
                      Text('room_chat.no_messages'.tr(),
                        style: TextStyle(
                            color: context.appTextSecColor.withOpacity(0.5),
                            fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: widget.messages.length,
                  itemBuilder: (ctx, i) => AppEntrance(
                    offsetY: 8,
                    duration: const Duration(milliseconds: 280),
                    child: _buildMessage(context, widget.messages[i]),
                  ),
                ),
        ),
        ChatInputBar(
          controller:     widget.chatController,
          onSend:         widget.onSend,
          mentionables:   widget.users,
          isMuted:        widget.mutedUsers.contains(widget.currentUsername),
          accentColor:    appAccent,
          bgColor:        context.appSurfaceColor,
          inputFillColor: context.appSurfaceAltColor,
          textColor:      context.appTextPrimColor,
          hintColor:      context.appTextSecColor,
        ),
      ],
    );
  }

  Widget _buildMessage(BuildContext context, Map<String, String> msg) {
    final isSystem = msg['user'] == 'system';
    final isMe     = msg['user'] == widget.currentUsername;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            msg['text'] ?? '',
            style: TextStyle(
              color:      context.appTextSecColor.withOpacity(0.6),
              fontSize:   11,
              fontStyle:  FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final sender = msg['user'] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: isMe
                ? null
                : () => showUserProfileSheet(
                      context,
                      username:   sender,
                      myUsername: widget.currentUsername ?? '',
                    ),
            child: _buildMsgAvatar(context, sender, isMe, size: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: isMe
                          ? null
                          : () => showUserProfileSheet(
                                context,
                                username:   sender,
                                myUsername: widget.currentUsername ?? '',
                              ),
                      child: Text(
                        sender,
                        style: TextStyle(
                          color:      isMe ? appAccent : context.appTextSecColor,
                          fontSize:   11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Badge DJ en el chat también
                    if (_isUserDJ(sender)) ...[
                      const SizedBox(width: 4),
                      _DJBadge(),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      msg['time'] ?? '',
                      style: TextStyle(
                          color: context.appTextSecColor.withOpacity(0.5),
                          fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                MentionText(
                  text:        msg['text'] ?? '',
                  myUsername:  widget.currentUsername,
                  baseStyle:   TextStyle(
                      color: context.appTextPrimColor, fontSize: 13, height: 1.3),
                  accentColor: appAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Lista de usuarios ──────────────────────────────────────────────────────

  Widget _buildUsers(BuildContext context) {
    final hasBanned = widget.isHost && widget.kickedUsers.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Usuarios activos
        ...widget.users.map((u) => _buildUserTile(context, u)),

        // Sección Baneados — solo visible para el host
        if (hasBanned) ...[
          const SizedBox(height: 12),
          _bannedSectionHeader(),
          ...widget.kickedUsers.map((u) => _buildBannedTile(context, u)),
        ],
      ],
    );
  }

  Widget _bannedSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: appError, size: 13),
          const SizedBox(width: 5),
          Text(
            'room_chat.banned_count'.tr(namedArgs: {'n': '${widget.kickedUsers.length}'}),
            style: const TextStyle(
              color: appError,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannedTile(BuildContext context, String user) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: Stack(
        children: [
          _buildMsgAvatar(context, user, false, size: 36),
          // Icono de ban superpuesto
          Positioned(
            bottom: -1, right: -1,
            child: Container(
              width: 15, height: 15,
              decoration: BoxDecoration(
                color: appError,
                shape: BoxShape.circle,
                border: Border.all(color: context.appSurfaceColor, width: 1.5),
              ),
              child: const Icon(Icons.block_rounded,
                  color: Colors.white, size: 8),
            ),
          ),
        ],
      ),
      title: Text(
        user,
        style: TextStyle(
          color: context.appTextDimColor,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.lineThrough,
          decorationColor: context.appTextDimColor,
        ),
      ),
      subtitle: Text('room_chat.banned_label'.tr(),
        style: TextStyle(color: appError, fontSize: 10),
      ),
      trailing: TextButton.icon(
        icon: const Icon(Icons.lock_open_rounded, size: 14),
        label: Text('room_chat.unban_button'.tr(), style: TextStyle(fontSize: 11)),
        style: TextButton.styleFrom(
          foregroundColor: appSuccess,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => widget.onUnkick?.call(user),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, String user) {
    final isMe      = user == widget.currentUsername;
    final isHost    = _isUserHost(user);
    final isDJ      = _isUserDJ(user);
    final isMuted   = _isUserMuted(user);

    // El host no puede actuar sobre sí mismo ni sobre otro host
    final canActOn  = widget.isHost && !isMe && !isHost;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onTap: isMe
          ? null
          : () => showUserProfileSheet(
                context,
                username:   user,
                myUsername: widget.currentUsername ?? '',
              ),

      // ── Avatar ───────────────────────────────────────────────────────────
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildMsgAvatar(context, user, isMe, size: 36),
          // Indicador de silenciado — esquina inferior derecha del avatar
          if (isMuted)
            Positioned(
              bottom: -2, right: -2,
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color:  appError,
                  shape:  BoxShape.circle,
                  border: Border.all(color: context.appSurfaceColor, width: 1.5),
                ),
                child: const Icon(Icons.mic_off,
                    color: Colors.white, size: 8),
              ),
            ),
        ],
      ),

      // ── Nombre ───────────────────────────────────────────────────────────
      title: Text(
        user + (isMe ? ' (tú)' : ''),
        style: TextStyle(
          color:      isMe ? appAccent : context.appTextPrimColor,
          fontSize:   13,
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Badge de rol ─────────────────────────────────────────────────────
      subtitle: isHost
          ? null
          : isDJ
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [_DJBadge()],
                )
              : null,

      // ── Acciones del host ─────────────────────────────────────────────────
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge de rol para el host
          if (isHost)
            _RoleBadge(label: 'Host', color: appAccent),

          // Menú de acciones — solo visible para el host, sobre usuarios no-host
          if (canActOn)
            _ModerationMenu(
              username:   user,
              isDJ:       isDJ,
              isMuted:    isMuted,
              onPromoteDJ: () => widget.onPromoteDJ?.call(user),
              onDemote:    () => widget.onDemote?.call(user),
              onMute:      () => widget.onMute?.call(user),
              onUnmute:    () => widget.onUnmute?.call(user),
              onKick:      () => _confirmKick(user),
            ),
        ],
      ),
    );
  }

  // ── Avatar helper ──────────────────────────────────────────────────────────

  Widget _buildMsgAvatar(BuildContext context, String username, bool isMe,
      {required double size}) {
    final avatarUrl = widget.userAvatars[username];
    final initial   = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final bgColor   = isMe ? appAccent.withOpacity(0.2) : context.appSurfaceAltColor;
    final borderColor = isMe ? appAccent.withOpacity(0.4) : appDivider;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: ClipOval(
          child: AppImage(
            url: avatarUrl,
            width: size, height: size,
            errorBuilder: (c) => _avatarInitial(
                c, initial, bgColor, borderColor, size),
          ),
        ),
      );
    }
    return _avatarInitial(context, initial, bgColor, borderColor, size);
  }

  Widget _avatarInitial(
      BuildContext context, String initial, Color bg, Color border, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        color:  bg,
        border: Border.all(color: border),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color:      context.appTextSecColor,
            fontSize:   size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Diálogo de confirmación antes de expulsar — acción irreversible
  void _confirmKick(String targetUsername) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('room_chat.kick_title'.tr()),
        content: Text(
            'room_chat.kick_confirm'.tr(namedArgs: {'user': targetUsername})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: appError),
            onPressed: () {
              Navigator.pop(context);
              widget.onKick?.call(targetUsername);
            },
            child: Text('groups.kick'.tr()),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

class _DJBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:         const Color(0xFF2A1F6B),
        borderRadius:  BorderRadius.circular(4),
        border:        Border.all(color: roomAccent.withOpacity(0.5)),
      ),
      child: Text('room.role_dj'.tr(),
        style: TextStyle(
          color:      roomAccent,
          fontSize:   9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:         color.withOpacity(0.15),
        borderRadius:  BorderRadius.circular(6),
        border:        Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Menú de tres puntos con las acciones de moderación disponibles para el host
class _ModerationMenu extends StatelessWidget {
  final String username;
  final bool   isDJ;
  final bool   isMuted;
  final VoidCallback onPromoteDJ;
  final VoidCallback onDemote;
  final VoidCallback onMute;
  final VoidCallback onUnmute;
  final VoidCallback onKick;

  const _ModerationMenu({
    required this.username,
    required this.isDJ,
    required this.isMuted,
    required this.onPromoteDJ,
    required this.onDemote,
    required this.onMute,
    required this.onUnmute,
    required this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: context.appTextSecColor, size: 18),
      color: context.appSurfaceAltColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd)),
      tooltip: 'room_chat.actions'.tr(),
      onSelected: (value) {
        switch (value) {
          case 'promote': onPromoteDJ();
          case 'demote':  onDemote();
          case 'mute':    onMute();
          case 'unmute':  onUnmute();
          case 'kick':    onKick();
        }
      },
      itemBuilder: (_) => [
        // Rol
        if (!isDJ)
          _menuItem(
            value: 'promote',
            icon:  Icons.queue_music_rounded,
            label: 'Hacer DJ',
            color: appAccent,
          )
        else
          _menuItem(
            value: 'demote',
            icon:  Icons.person_outline,
            label: 'Quitar DJ',
            color: context.appTextSecColor,
          ),

        const PopupMenuDivider(),

        // Silenciar / Dessilenciar
        if (!isMuted)
          _menuItem(
            value: 'mute',
            icon:  Icons.mic_off_outlined,
            label: 'Silenciar',
            color: context.appTextSecColor,
          )
        else
          _menuItem(
            value: 'unmute',
            icon:  Icons.mic_outlined,
            label: 'Quitar silencio',
            color: appSuccess,
          ),

        const PopupMenuDivider(),

        // Expulsar — rojo para indicar que es destructivo
        _menuItem(
          value: 'kick',
          icon:  Icons.person_remove_outlined,
          label: 'room_chat.kick_button'.tr(),
          color: appError,
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem({
    required String   value,
    required IconData icon,
    required String   label,
    required Color    color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}