import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viber/core/services/notification_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/utils/haptics.dart';
import 'package:viber/core/widgets/motion.dart';
import 'features/chat/infrastructure/chat_service.dart';
import 'features/chat/presentation/conversations_screen.dart';
import 'features/notifications/notifications_sheet.dart';
import 'features/rooms/domain/room.dart';
import 'features/rooms/infrastructure/room_service.dart';
import 'features/rooms/presentation/active_room_provider.dart';
import 'features/rooms/presentation/rooms_screen.dart';
import 'features/rooms/presentation/explore_screen.dart';
import 'features/quiz/presentation/quiz_home_screen.dart';
import 'features/social/infrastructure/friendship_service.dart';
import 'features/social/domain/user_profile.dart';
import 'features/social/presentation/friends_screen.dart';
import 'features/groups/domain/group_models.dart';
import 'features/groups/infrastructure/group_service.dart';
import 'features/quiz/domain/match_models.dart';
import 'features/quiz/infrastructure/quiz_match_socket.dart';
import 'features/quiz/presentation/match_screen.dart';
import './features/social/presentation/profile_screen.dart';
import './features/social/presentation/settings_screen.dart';
import 'features/admin/presentation/admin_screen.dart';
import 'features/auth/infrastructure/auth_service.dart';

/// Pantalla principal con barra de navegación inferior (Salas / Explorar / Mensajes).
///
/// Gestiona:
///  - Polling de mensajes no leídos cada 10 s (badge del tab de chat).
///  - Polling unificado de notificaciones (invitaciones + solicitudes de amistad) cada 15 s.
///  - Apertura del sheet de notificaciones y unión a sala por invitación.
///  - Comprobación del rol admin para mostrar el icono del panel de administración.
class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _friendshipService = FriendshipService();
  final _chatService       = ChatService();
  final _authService       = AuthService();
  final _groupService      = GroupService();

  List<RoomInvitation>       _invitations      = [];
  List<UserProfile>          _friendRequests   = [];
  List<GroupInvitationModel> _groupInvitations = [];
  int  _selectedTab  = 0;
  bool _joiningRoom  = false;
  int  _lastUnread   = 0;
  bool _isAdmin      = false;

  Timer? _unreadTimer;
  Timer? _notifTimer;
  QuizInviteSocket? _inviteSocket;

  int get _notifCount =>
      _invitations.length + _friendRequests.length + _groupInvitations.length;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _refreshUnread();
    _refreshNotifications();
    _initInviteSocket();
    _unreadTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshUnread(),
    );
    // Polling unificado de notificaciones cada 15 s
    _notifTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshNotifications(),
    );
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _notifTimer?.cancel();
    _inviteSocket?.disconnect();
    super.dispose();
  }

  // ── Invitaciones a duelo de quiz (en vivo) ──────────────────────────────────

  Future<void> _initInviteSocket() async {
    final token = await _authService.getToken();
    if (token == null || !mounted) return;
    _inviteSocket = QuizInviteSocket(token: token)
      ..onInvite = _onQuizInvite
      ..connect();
  }

  void _onQuizInvite(MatchInvite invite) {
    if (!mounted) return;
    NotificationService.playNotificationSound();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'home.quiz_challenge_from'.tr(namedArgs: {'user': '${invite.from}'}),
            style: const TextStyle(fontSize: 13))),
        ],
      ),
      backgroundColor: appAccent,
      behavior: SnackBarBehavior.floating,
      width: 340,
      duration: const Duration(seconds: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      action: SnackBarAction(
        label: 'Unirse',
        textColor: Colors.white,
        onPressed: () => Navigator.push(
          context, fadeThroughRoute(MatchScreen(matchId: invite.matchId))),
      ),
    ));
  }

  Future<void> _checkAdmin() async {
    final admin = await _authService.isAdmin();
    if (mounted) setState(() => _isAdmin = admin);
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  Future<void> _refreshUnread() async {
    try {
      final convs = await _chatService.getConversations();
      if (!mounted) return;
      final newUnread = convs.where((c) => ChatService.isUnread(c)).length;
      ChatService.updateUnread(convs);
      if (newUnread != _lastUnread) _lastUnread = newUnread;
    } catch (_) {}
  }

  Future<void> _refreshNotifications() async {
    try {
      final results = await Future.wait([
        _friendshipService.getInvitations(),
        _friendshipService.getPending(),
        _groupService.getInvitations(),
      ]);

      if (!mounted) return;

      final newInvitations      = results[0] as List<RoomInvitation>;
      final newFriendRequests   = results[1] as List<UserProfile>;
      final newGroupInvitations = results[2] as List<GroupInvitationModel>;

      // Detectar llegadas nuevas para mostrar snackbar discreto
      final addedInvites  = newInvitations.map((i) => i.id).toSet()
          .difference(_invitations.map((i) => i.id).toSet());
      final addedRequests = newFriendRequests.map((p) => p.username).toSet()
          .difference(_friendRequests.map((p) => p.username).toSet());
      final addedGroups   = newGroupInvitations.map((i) => i.id).toSet()
          .difference(_groupInvitations.map((i) => i.id).toSet());

      setState(() {
        _invitations      = newInvitations;
        _friendRequests   = newFriendRequests;
        _groupInvitations = newGroupInvitations;
      });

      // Actualizar título de pestaña con el total de notificaciones pendientes
      NotificationService.updateTabTitle(_notifCount);

      if (addedInvites.isNotEmpty) {
        final inv = newInvitations
            .firstWhere((i) => addedInvites.contains(i.id));
        NotificationService.playNotificationSound();
        _showSnackBar(
          'home.room_invite_from'.tr(namedArgs: {'user': '${inv.senderName}', 'room': '${inv.roomName}'}),
          icon: Icons.headphones_rounded,
        );
      }
      if (addedRequests.isNotEmpty) {
        final req = newFriendRequests
            .firstWhere((p) => addedRequests.contains(p.username));
        NotificationService.playNotificationSound();
        _showSnackBar(
          'home.friend_request_from'.tr(namedArgs: {'user': '${req.displayLabel}'}),
          icon: Icons.person_add_alt_1_rounded,
        );
      }
      if (addedGroups.isNotEmpty) {
        final inv = newGroupInvitations
            .firstWhere((i) => addedGroups.contains(i.id));
        NotificationService.playNotificationSound();
        _showSnackBar(
          'home.group_invite_from'.tr(namedArgs: {'user': '${inv.senderName}', 'group': '${inv.groupName}'}),
          icon: Icons.groups_rounded,
        );
      }
    } catch (_) {}
  }

  // ── Notification sheet ─────────────────────────────────────────────────────

  void _openNotifications() {
    // Al abrir el sheet se considera "visto" → reset del título de pestaña
    NotificationService.updateTabTitle(0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationsSheet(
        invitations:      _invitations,
        friendRequests:   _friendRequests,
        groupInvitations: _groupInvitations,
        onJoin:              _handleJoinInvitation,
        onDismissInvitation: _handleDismissInvitation,
        onAcceptFriend:      _handleAcceptFriend,
        onRejectFriend:      _handleRejectFriend,
        onAcceptGroup:       _handleAcceptGroup,
        onRejectGroup:       _handleRejectGroup,
      ),
    );
  }

  Future<void> _handleAcceptGroup(int invId) async {
    await _groupService.acceptInvitation(invId);
    if (!mounted) return;
    setState(() => _groupInvitations.removeWhere((i) => i.id == invId));
    _showSnackBar('groups.joined'.tr(), icon: Icons.groups_rounded);
  }

  Future<void> _handleRejectGroup(int invId) async {
    await _groupService.rejectInvitation(invId);
    if (!mounted) return;
    setState(() => _groupInvitations.removeWhere((i) => i.id == invId));
    _showSnackBar('groups.invite_rejected'.tr());
  }

  Future<void> _handleDismissInvitation(int id) async {
    await _friendshipService.dismissInvitation(id);
    if (!mounted) return;
    setState(() => _invitations.removeWhere((i) => i.id == id));
    _showSnackBar('home.invitation_dismissed'.tr());
  }

  Future<void> _handleJoinInvitation(RoomInvitation inv) async {
    Navigator.pop(context); // cerrar sheet
    await _joinFromInvitation(inv);
  }

  Future<void> _handleAcceptFriend(String username) async {
    await _friendshipService.acceptRequest(username);
    if (!mounted) return;
    setState(() =>
        _friendRequests.removeWhere((p) => p.username == username));
    _showSnackBar('friends.accepted_success'.tr(),
        icon: Icons.check_circle_outline);
  }

  Future<void> _handleRejectFriend(String username) async {
    await _friendshipService.removeFriend(username);
    if (!mounted) return;
    setState(() =>
        _friendRequests.removeWhere((p) => p.username == username));
    _showSnackBar('home.request_rejected'.tr());
  }

  // ── Unirse a sala ──────────────────────────────────────────────────────────

  Future<void> _joinFromInvitation(RoomInvitation inv) async {
    if (_joiningRoom) return;
    setState(() => _joiningRoom = true);
    _showSnackBar('home.connecting_to'.tr(namedArgs: {'room': '${inv.roomName}'}),
        icon: Icons.headphones_rounded, color: appAccent);
    try {
      final Room room;
      if (inv.accessCode != null && inv.accessCode!.isNotEmpty) {
        room = await RoomService().joinByCode(inv.accessCode!);
      } else {
        final rooms = await RoomService().getPublicRooms();
        room = rooms.firstWhere(
          (r) => r.id == inv.roomId,
          orElse: () => throw Exception('home.room_unavailable'.tr()),
        );
      }
      if (!mounted) return;
      await _openRoom(context, room);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e.toString().replaceAll('Exception: ', ''),
        icon: Icons.error_outline,
        color: appError,
      );
    } finally {
      if (mounted) setState(() => _joiningRoom = false);
    }
  }

  Future<void> _openRoom(BuildContext context, Room room) async {
    final provider = context.read<ActiveRoomProvider>();

    if (provider.isActive && provider.room?.id != room.id) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('home.switch_title'.tr()),
          content: Text(
            'home.currently_in'.tr(namedArgs: {'room': '${provider.room?.name}'}) +
                'home.switch_confirm'.tr(namedArgs: {'room': '${room.name}'}),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('common.cancel'.tr())),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('home.switch_button'.tr())),
          ],
        ),
      );
      if (confirm != true) return;
      provider.leaveRoom();
    }

    if (provider.isActive && provider.room?.id == room.id) {
      provider.expand();
      return;
    }

    final kicked = await RoomService().isKickedFromRoom(room.id);
    if (!context.mounted) return;

    if (kicked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'home.kicked_no_rejoin'.tr(namedArgs: {'room': '${room.name}'}),
          style: const TextStyle(fontSize: 13),
        ),
        backgroundColor: appError,    // error siempre es el mismo color
        behavior: SnackBarBehavior.floating,
        width: 360,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
      ));
      return;
    }

    Haptics.medium();
    provider.joinRoom(room);
  }

  // ── Snackbar helper ────────────────────────────────────────────────────────

  void _showSnackBar(String msg, {IconData? icon, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ],
      ),
      backgroundColor: color, // null → el SnackBarTheme decide el color
      behavior: SnackBarBehavior.floating,
      width: 340,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: FadeIndexedStack(
        index: _selectedTab,
        children: [
          RoomsScreen(onEnterRoom: (Room room) => _openRoom(context, room)),
          ExploreScreen(onEnterRoom: (Room room) => _openRoom(context, room)),
          const QuizHomeScreen(),
          const ConversationsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      titleSpacing: spacingMd,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/brand/isotipo.png', height: 30),
          const SizedBox(width: spacingSm),
          Text(
            'Viber',
            style: TextStyle(
              fontFamily: 'Fredoka',
              color: context.appTextPrimColor,
              fontWeight: FontWeight.w600,
              fontSize: 22,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        // ── Campana de notificaciones ──────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                _notifCount > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                color: _notifCount > 0 ? appAccent : null,
              ),
              tooltip: 'nav.notifications'.tr(),
              onPressed: _openNotifications,
            ),
            if (_notifCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_notifCount),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  builder: (_, t, child) =>
                      Transform.scale(scale: t, child: child),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: appAccent,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: context.appSurfaceColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        _notifCount > 99 ? '99+' : '$_notifCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.group_outlined),
          tooltip: 'common.friends'.tr(),
          onPressed: () => Navigator.push(
            context,
            fadeThroughRoute(const FriendsScreen()),
          ).then((_) => _refreshNotifications()),
        ),
        // ── Menú de cuenta (perfil / administración / ajustes) ─────────────
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle_outlined),
          tooltip: 'nav.account'.tr(),
          position: PopupMenuPosition.under,
          onSelected: (value) {
            switch (value) {
              case 'profile':
                Navigator.push(
                  context,
                  fadeThroughRoute(ProfileScreen(onLogout: widget.onLogout)),
                );
                break;
              case 'admin':
                Navigator.push(
                  context,
                  fadeThroughRoute(const AdminScreen()),
                );
                break;
              case 'settings':
                Navigator.push(
                  context,
                  fadeThroughRoute(SettingsScreen(onLogout: widget.onLogout)),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: _AccountMenuRow(
                icon: Icons.person_outlined,
                label: 'profile.my_profile'.tr(),
              ),
            ),
            if (_isAdmin)
              PopupMenuItem(
                value: 'admin',
                child: _AccountMenuRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'nav.admin'.tr(),
                ),
              ),
            const PopupMenuItem(
              value: 'settings',
              child: _AccountMenuRow(
                icon: Icons.settings_outlined,
                label: 'Ajustes',
              ),
            ),
          ],
        ),
        const SizedBox(width: spacingXs),
      ],
    );
  }

  // El badge de chat ya no puede ser static porque necesita context para el color del borde
  Widget _chatIcon(IconData icon, int unread, {Color? color}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (unread > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appSurfaceColor, width: 1.5),
              ),
              child: Center(
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        border: Border(top: BorderSide(color: appDivider)),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: ChatService.unreadNotifier,
        builder: (_, unread, __) {
          return NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (i) {
              Haptics.selection();
              setState(() => _selectedTab = i);
            },
            labelBehavior:
                NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.headphones_outlined),
                selectedIcon:
                    Icon(Icons.headphones_rounded, color: appAccent),
                label: 'Salas',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon:
                    Icon(Icons.explore_rounded, color: appAccent),
                label: 'explore.title'.tr(),
              ),
              const NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon:
                    Icon(Icons.sports_esports_rounded, color: appAccent),
                label: 'Quiz',
              ),
              NavigationDestination(
                icon: _chatIcon(
                    Icons.chat_bubble_outline_rounded, unread),
                selectedIcon: _chatIcon(
                    Icons.chat_bubble_rounded, unread,
                    color: appAccent),
                label: 'chat.messages_title'.tr(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fila de un ítem del menú de cuenta (icono + etiqueta) en el AppBar.
class _AccountMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AccountMenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.appTextPrimColor),
        const SizedBox(width: spacingMd),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
