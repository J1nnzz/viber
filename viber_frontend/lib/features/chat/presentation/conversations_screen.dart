import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/skeletons.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../infrastructure/chat_service.dart';
import '../domain/chat_message.dart';
import '../../social/infrastructure/friendship_service.dart';
import '../../social/domain/user_profile.dart';
import '../../groups/domain/group_models.dart';
import '../../groups/infrastructure/group_service.dart';
import '../../groups/presentation/create_group_screen.dart';
import '../../groups/presentation/group_avatar.dart';
import '../../groups/presentation/group_chat_screen.dart';
import 'direct_chat_screen.dart';
import 'global_chat_screen.dart';

/// Tab "Mensajes" de la navegación principal.
///
/// Muestra la lista de conversaciones privadas con badge de no leídos y un acceso
/// al chat global. Permite iniciar una nueva conversación con cualquier amigo.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _chatService       = ChatService();
  final _friendshipService = FriendshipService();
  final _groupService      = GroupService();

  List<Conversation> _conversations = [];
  List<UserProfile>  _friends       = [];
  List<GroupModel>   _groups        = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _fetchData();
  }

  Future<void> _refresh() async {
    await _fetchData();
  }

  Future<void> _fetchData() async {
    final convsResult = await _chatService.getConversations()
        .catchError((_) => <Conversation>[]);
    final friendsResult = _friends.isEmpty
        ? await _friendshipService.getFriends()
            .catchError((_) => <UserProfile>[])
        : _friends;
    final groupsResult = await _groupService.getMyGroups()
        .catchError((_) => <GroupModel>[]);

    if (!mounted) return;
    setState(() {
      _conversations = convsResult;
      _friends       = friendsResult;
      _groups        = groupsResult;
      _loading       = false;
    });
    ChatService.updateUnread(convsResult);
  }

  Future<void> _createGroup() async {
    final created = await Navigator.push<GroupModel>(
      context, fadeThroughRoute(const CreateGroupScreen()));
    if (created != null && mounted) {
      await _refresh();
      if (mounted) _openGroup(created);
    }
  }

  void _openGroup(GroupModel group) {
    Navigator.push(context, fadeThroughRoute(GroupChatScreen(group: group)))
        .then((_) => _refresh());
  }

  void _openDM(String username, {String? displayName, String? avatarUrl}) {
    Navigator.push(
      context,
      fadeThroughRoute(
        DirectChatScreen(
          otherUsername:    username,
          otherDisplayName: displayName,
          otherAvatarUrl:   avatarUrl,
        ),
      ),
    ).then((_) => _refresh());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('chat.messages_title'.tr()),
      ),
      body: _loading
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: _load,
              color: appAccent,
              child: CustomScrollView(
                slivers: [
                  // ── Chat Global ─────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildGlobalTile()),
                  SliverToBoxAdapter(
                    child: Divider(height: 1, color: appDivider),
                  ),

                  // ── Grupos ──────────────────────────────────────────────
                  SliverToBoxAdapter(child: _buildGroupsHeader()),
                  if (_groups.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => AppEntrance(
                          delay: Duration(milliseconds: (i.clamp(0, 8)) * 40),
                          child: _buildGroupTile(_groups[i]),
                        ),
                        childCount: _groups.length,
                      ),
                    )
                  else
                    SliverToBoxAdapter(child: _buildEmptyHint(
                      'Crea un grupo para chatear con varios amigos a la vez.',
                    )),
                  SliverToBoxAdapter(
                    child: Divider(height: 1, color: appDivider),
                  ),

                  // ── Conversaciones ──────────────────────────────────────
                  _sectionHeader('chat.conversations_header'.tr()),
                  if (_conversations.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => AppEntrance(
                          delay: Duration(milliseconds: (i.clamp(0, 8)) * 40),
                          child: _buildConvTile(_conversations[i]),
                        ),
                        childCount: _conversations.length,
                      ),
                    )
                  else
                    SliverToBoxAdapter(child: _buildEmptyHint(
                      'chat.no_conversations'.tr(),
                    )),

                  // ── Amigos ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Divider(height: 1, color: appDivider),
                  ),
                  _sectionHeader('chat.friends_header'.tr()),
                  if (_friends.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyHint(
                      'chat.no_friends_chat'.tr(),
                    ))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => AppEntrance(
                          delay: Duration(milliseconds: (i.clamp(0, 8)) * 40),
                          child: _buildFriendTile(_friends[i]),
                        ),
                        childCount: _friends.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  SliverToBoxAdapter _sectionHeader(String label) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            spacingMd, spacingMd, spacingMd, spacingXs),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          spacingMd, spacingXs, spacingMd, spacingMd),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Grupos ───────────────────────────────────────────────────────────────────

  Widget _buildGroupsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(spacingMd, spacingMd, spacingXs, spacingXs),
      child: Row(
        children: [
          Text(
            'groups.section'.tr(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: appAccent, size: 22),
            tooltip: 'groups.create_group'.tr(),
            onPressed: _createGroup,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(GroupModel group) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openGroup(group),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: 12),
          child: Row(
            children: [
              GroupAvatar(name: group.name, photoUrl: group.photoUrl, radius: 22),
              const SizedBox(width: spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'groups.members_count'.tr(namedArgs: {'n': '${group.memberCount}'}),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat Global tile ───────────────────────────────────────────────────────

  Widget _buildGlobalTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          fadeThroughRoute(const GlobalChatScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: spacingMd, vertical: 14),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: appAccentGlow,
                  borderRadius: BorderRadius.circular(radiusMd),
                  border: Border.all(color: appDivider),
                ),
                child: const Icon(Icons.public_rounded,
                    color: appAccent, size: 22),
              ),
              const SizedBox(width: spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chat.global_title'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'chat.global_subtitle'.tr(),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Conversation tile ──────────────────────────────────────────────────────

  Widget _buildConvTile(Conversation conv) {
    final friend = _friends.firstWhere(
      (f) => f.username == conv.otherUser,
      orElse: () => UserProfile(id: 0, username: conv.otherUser, email: ''),
    );
    final unread = ChatService.isUnread(conv);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDM(
          friend.username,
          displayName: friend.displayName,
          avatarUrl:   friend.avatarUrl,
        ),
        child: Container(
          color: unread ? appAccentDim : Colors.transparent,
          child: Row(
            children: [
              // Accent edge bar when unread
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width:  unread ? 3 : 0,
                height: 72,
                color: appAccent,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    unread ? spacingSm : spacingMd,
                    12, spacingMd, 12,
                  ),
                  child: Row(
                    children: [
                      // Avatar with optional unread dot
                      _unreadAvatar(
                        friend.username,
                        friend.avatarUrl,
                        showDot: unread,
                      ),
                      const SizedBox(width: spacingMd),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friend.displayLabel,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (conv.lastMessage != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${conv.lastSender == null ? "" : "${conv.lastSender}: "}'
                                '${conv.lastMessage}',
                                style: TextStyle(
                                  color: unread
                                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                                  fontWeight: unread
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: spacingXs),
                      // Trailing indicator
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: appAccent,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Friend tile ────────────────────────────────────────────────────────────

  Widget _buildFriendTile(UserProfile p) {
    if (_conversations.any((c) => c.otherUser == p.username)) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDM(
            p.username,
            displayName: p.displayName,
            avatarUrl:   p.avatarUrl),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: spacingMd, vertical: 12),
          child: Row(
            children: [
              _avatarWidget(p.username, p.avatarUrl),
              const SizedBox(width: spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${p.username}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar helpers ─────────────────────────────────────────────────────────

  Widget _unreadAvatar(String username, String? avatarUrl,
      {required bool showDot}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _avatarWidget(username, avatarUrl),
        if (showDot)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color:  appAccent,
                shape:  BoxShape.circle,
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarWidget(String username, String? avatarUrl,
      {double radius = 22}) {
    return UserAvatar(username: username, avatarUrl: avatarUrl, radius: radius);
  }
}
