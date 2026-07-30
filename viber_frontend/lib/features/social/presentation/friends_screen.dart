import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/skeletons.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../infrastructure/friendship_service.dart';
import '../domain/user_profile.dart';
import '../../rooms/presentation/active_room_provider.dart';

/// Pantalla de gestión de amigos con tres pestañas: amigos actuales (con presencia
/// en tiempo real), solicitudes pendientes y búsqueda de usuarios.
/// La presencia se actualiza cada 10 s para mostrar si un amigo está en una sala.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final _service = FriendshipService();
  late TabController _tabController;
  Timer? _statusTimer;
  Timer? _debounce;

  List<UserProfile>  _friends       = [];
  List<UserProfile>  _pending       = [];
  List<FriendStatus> _statuses      = [];
  List<UserProfile>  _searchResults = [];
  bool _loadingFriends = true;
  bool _loadingPending = true;

  final _searchCtrl = TextEditingController();
  bool    _searching = false;
  String? _searchErr;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshStatuses(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _debounce?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshStatuses() async {
    try {
      final statuses = await _service.getFriendsStatus();
      if (mounted) setState(() => _statuses = statuses);
    } catch (_) {}
  }

  Future<void> _loadAll() =>
      Future.wait([_loadFriends(), _loadPending()]);

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    try {
      final results = await Future.wait([
        _service.getFriends(),
        _service.getFriendsStatus(),
      ]);
      if (mounted) {
        setState(() {
          _friends  = results[0] as List<UserProfile>;
          _statuses = results[1] as List<FriendStatus>;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _loadPending() async {
    setState(() => _loadingPending = true);
    try {
      final p = await _service.getPending();
      if (mounted) setState(() => _pending = p);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  FriendStatus? _statusOf(String username) {
    try {
      return _statuses.firstWhere((s) => s.username == username);
    } catch (_) {
      return null;
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() { _searchResults = []; _searching = false; _searchErr = null; });
      return;
    }
    setState(() { _searching = true; _searchErr = null; });
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    try {
      final results = await _service.searchUsers(q);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) setState(() => _searchErr = 'friends.search_error'.tr());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(String username) async {
    try {
      await _service.sendRequest(username);
      if (mounted) AppSnackBar.show(context,
          'friends.request_sent'.tr(args: [username]));
      if (_searchCtrl.text.trim().length >= 2) {
        _doSearch(_searchCtrl.text.trim());
      }
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _accept(String username) async {
    try {
      await _service.acceptRequest(username);
      await _loadAll();
      if (mounted) AppSnackBar.show(context, 'friends.accepted_success'.tr());
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _remove(String username) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('profile.delete_dialog_title'.tr(),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('profile.delete_confirmation'.tr(args: [username]),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('common.cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('common.delete'.tr(),
                  style: const TextStyle(color: appError))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.removeFriend(username);
      await _loadFriends();
      if (mounted) AppSnackBar.show(context,
          'friends.deleted_success'.tr(args: [username]));
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _reject(String username) async {
    try {
      await _service.removeFriend(username);
      await _loadPending();
      if (mounted) AppSnackBar.show(context,
          'friends.rejected_success'.tr(args: [username]));
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _invite(String username, int roomId) async {
    try {
      await _service.inviteFriend(username, roomId);
      if (mounted) AppSnackBar.show(context,
          'friends.invitation_sent'.tr(args: [username]));
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('friends.title'.tr()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: appAccent,
            indicatorWeight: 2,
            labelColor: appAccent,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: [
              Tab(text: 'friends.tab_friends'.tr()),
              Tab(
                text: _pending.isEmpty
                    ? 'friends.tab_requests'.tr()
                    : 'friends.tab_requests_count'
                        .tr(args: ['${_pending.length}']),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFriendsTab(), _buildPendingTab()],
      ),
    );
  }

  // ── Tab: Amigos ────────────────────────────────────────────────────────────

  Widget _buildFriendsTab() {
    final provider     = context.watch<ActiveRoomProvider>();
    final activeRoomId = provider.isActive ? provider.room?.id : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              spacingMd, spacingMd, spacingMd, spacingXs),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'friends.search_placeholder'.tr(),
              prefixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: appAccent),
                      ),
                    )
                  : const Icon(Icons.person_search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _searchResults = []; _searchErr = null; });
                      },
                    )
                  : null,
            ),
          ),
        ),
        if (_searchErr != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                spacingMd, 0, spacingMd, spacingXs),
            child: Text(_searchErr!,
                style: const TextStyle(color: appError, fontSize: 12)),
          ),
        if (_searchResults.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                spacingMd, 0, spacingMd, spacingXs),
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) => const SizedBox(height: spacingXs),
            itemBuilder: (_, i) => _SearchResultCard(
              profile: _searchResults[i],
              onAdd: () => _sendRequest(_searchResults[i].username),
            ),
          ),
          Divider(height: 1, color: appDivider),
        ] else if (_searchCtrl.text.trim().length >= 2 && !_searching) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                spacingMd, 0, spacingMd, spacingXs),
            child: Text(
              'friends.no_results'.tr(args: [_searchCtrl.text.trim()]),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                  fontSize: 12),
            ),
          ),
          Divider(height: 1, color: appDivider),
        ] else
          Divider(height: 1, color: appDivider),

        Expanded(
          child: _loadingFriends
              ? const SkeletonList()
              : _friends.isEmpty
                  ? _buildEmpty('friends.no_friends'.tr())
                  : RefreshIndicator(
                      onRefresh: _loadFriends,
                      color: appAccent,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            vertical: spacingXs),
                        itemCount: _friends.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: appAccent.withValues(alpha: 0.2),
                            indent: 72,
                            endIndent: spacingMd),
                        itemBuilder: (_, i) => AppEntrance(
                          delay: Duration(milliseconds: (i.clamp(0, 8)) * 40),
                          child: _buildFriendTile(
                            _friends[i],
                            activeRoomId: activeRoomId,
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFriendTile(UserProfile p, {int? activeRoomId}) {
    final status = _statusOf(p.username);
    final inRoom = status?.isInRoom ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: spacingMd, vertical: 10),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              UserAvatar(username: p.username, avatarUrl: p.avatarUrl),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: inRoom
                        ? appSuccess
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2),
                  ),
                ),
              ),
            ],
          ),
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
                if (inRoom && status?.roomName != null)
                  Row(
                    children: [
                      const Icon(Icons.headphones_rounded,
                          color: appEnergy, size: 11),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          status!.roomName!,
                          style: const TextStyle(
                            color: appEnergy,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '@${p.username}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                        fontSize: 11),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeRoomId != null)
                _IconAction(
                  icon: Icons.person_add_alt_1_rounded,
                  color: appAccent,
                  tooltip: 'friends.invite_tooltip'.tr(),
                  onTap: () => _invite(p.username, activeRoomId),
                ),
              _IconAction(
                icon: Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                tooltip: 'friends.delete_tooltip'.tr(),
                onTap: () => _remove(p.username),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab: Solicitudes ───────────────────────────────────────────────────────

  Widget _buildPendingTab() {
    return _loadingPending
        ? const SkeletonList()
        : _pending.isEmpty
            ? _buildEmpty('friends.no_requests'.tr())
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: spacingXs),
                itemCount: _pending.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: appDivider,
                    indent: 72,
                    endIndent: spacingMd),
                itemBuilder: (_, i) => AppEntrance(
                  delay: Duration(milliseconds: (i.clamp(0, 8)) * 40),
                  child: _buildPendingTile(_pending[i]),
                ),
              );
  }

  Widget _buildPendingTile(UserProfile p) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: spacingMd, vertical: 10),
      child: Row(
        children: [
          UserAvatar(username: p.username, avatarUrl: p.avatarUrl),
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
                  'friends.request_message'.tr(args: [p.username]),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: spacingXs),
          _IconAction(
            icon: Icons.check_circle_outline,
            color: appSuccess,
            tooltip: 'common.accept'.tr(),
            onTap: () => _accept(p.username),
          ),
          _IconAction(
            icon: Icons.cancel_outlined,
            color: appError,
            tooltip: 'common.reject'.tr(),
            onTap: () => _reject(p.username),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildEmpty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.appAccentGlowColor,
                borderRadius: BorderRadius.circular(radiusXl),
              ),
              child: const Icon(Icons.group_outlined,
                  color: appAccent, size: 34),
            ),
            const SizedBox(height: spacingLg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search result card ────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onAdd;
  const _SearchResultCard({required this.profile, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: spacingSm),
      padding: const EdgeInsets.all(spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: appDivider),
      ),
      child: Row(
        children: [
          UserAvatar(username: profile.username, avatarUrl: profile.avatarUrl),
          const SizedBox(width: spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (profile.username != profile.displayLabel)
                  Text(
                    '@${profile.username}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12),
                  ),
                if (profile.bio != null && profile.bio!.isNotEmpty)
                  Text(
                    profile.bio!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: spacingSm),
          if (profile.relation == 'NONE')
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('common.add'.tr(),
                  style: const TextStyle(fontSize: 12)),
            )
          else if (profile.relation == 'PENDING_SENT')
            Text('common.pending'.tr(),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    fontSize: 12))
          else if (profile.relation == 'FRIENDS')
            Row(
              children: [
                const Icon(Icons.check_rounded, color: appSuccess, size: 14),
                const SizedBox(width: 4),
                Text('common.friends'.tr(),
                    style: const TextStyle(color: appSuccess, fontSize: 12)),
              ],
            )
          else if (profile.relation == 'SELF')
            Text('common.you'.tr(),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Icon action button ────────────────────────────────────────────────────────

class _IconAction extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(spacingXs + 2),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
