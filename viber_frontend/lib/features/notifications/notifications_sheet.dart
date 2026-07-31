import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../social/domain/user_profile.dart';
import '../groups/domain/group_models.dart';
import '../groups/presentation/group_avatar.dart';

/// Bottom sheet de notificaciones que agrupa invitaciones de sala, invitaciones
/// a grupo y solicitudes de amistad pendientes. El HomeScreen lo abre desde la
/// campana de la AppBar.
class NotificationsSheet extends StatefulWidget {
  final List<RoomInvitation>       invitations;
  final List<UserProfile>          friendRequests;
  final List<GroupInvitationModel> groupInvitations;
  final Future<void> Function(RoomInvitation inv) onJoin;
  final Future<void> Function(int id)             onDismissInvitation;
  final Future<void> Function(String username)    onAcceptFriend;
  final Future<void> Function(String username)    onRejectFriend;
  final Future<void> Function(int invId)          onAcceptGroup;
  final Future<void> Function(int invId)          onRejectGroup;

  const NotificationsSheet({
    super.key,
    required this.invitations,
    required this.friendRequests,
    required this.groupInvitations,
    required this.onJoin,
    required this.onDismissInvitation,
    required this.onAcceptFriend,
    required this.onRejectFriend,
    required this.onAcceptGroup,
    required this.onRejectGroup,
  });

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  // Seguimiento de items en proceso para mostrar loading por separado
  final Set<String> _busy = {};

  bool _isBusy(String key) => _busy.contains(key);

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busy.add(key));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.invitations.length +
        widget.friendRequests.length +
        widget.groupInvitations.length;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPad + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.notifications_rounded,
                    color: appAccent, size: 20),
                const SizedBox(width: 8),
                Text('nav.notifications'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (totalCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: appAccent,
                      borderRadius: BorderRadius.circular(radiusFull),
                    ),
                    child: Text(
                      '$totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (totalCount == 0)
            _buildEmpty()
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  // ── Solicitudes de amistad ───────────────────────────────
                  if (widget.friendRequests.isNotEmpty) ...[
                    _sectionHeader('notifications.friend_requests_header'.tr(),
                        widget.friendRequests.length),
                    ...widget.friendRequests.indexed.map((e) {
                      final p = e.$2;
                      return AppEntrance(
                        delay: Duration(milliseconds: e.$1 * 55),
                        child: _FriendRequestTile(
                          profile: p,
                          acceptBusy: _isBusy('fa_${p.username}'),
                          rejectBusy: _isBusy('fr_${p.username}'),
                          onAccept: () => _run('fa_${p.username}',
                              () => widget.onAcceptFriend(p.username)),
                          onReject: () => _run('fr_${p.username}',
                              () => widget.onRejectFriend(p.username)),
                        ),
                      );
                    }),
                  ],

                  // ── Invitaciones a grupo ─────────────────────────────────
                  if (widget.groupInvitations.isNotEmpty) ...[
                    _sectionHeader(
                        'INVITACIONES A GRUPO', widget.groupInvitations.length),
                    ...widget.groupInvitations.indexed.map((e) {
                      final inv = e.$2;
                      return AppEntrance(
                        delay: Duration(milliseconds: e.$1 * 55),
                        child: _GroupInvitationTile(
                          invitation: inv,
                          acceptBusy: _isBusy('ga_${inv.id}'),
                          rejectBusy: _isBusy('gr_${inv.id}'),
                          onAccept: () => _run('ga_${inv.id}',
                              () => widget.onAcceptGroup(inv.id)),
                          onReject: () => _run('gr_${inv.id}',
                              () => widget.onRejectGroup(inv.id)),
                        ),
                      );
                    }),
                  ],

                  // ── Invitaciones a sala ──────────────────────────────────
                  if (widget.invitations.isNotEmpty) ...[
                    _sectionHeader(
                        'notifications.room_invitations_header'.tr(), widget.invitations.length),
                    ...widget.invitations.indexed.map((e) {
                      final inv = e.$2;
                      return AppEntrance(
                        delay: Duration(milliseconds: e.$1 * 55),
                        child: _RoomInvitationTile(
                          invitation: inv,
                          joinBusy: _isBusy('ij_${inv.id}'),
                          dismissBusy: _isBusy('id_${inv.id}'),
                          onJoin: () => _run('ij_${inv.id}',
                              () => widget.onJoin(inv)),
                          onDismiss: () => _run('id_${inv.id}',
                              () => widget.onDismissInvitation(inv.id)),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(radiusFull),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(radiusXl),
            ),
            child: Icon(Icons.notifications_none_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 26),
          ),
          const SizedBox(height: 12),
          Text('notifications.empty'.tr(),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Tile: solicitud de amistad ────────────────────────────────────────────────

class _FriendRequestTile extends StatelessWidget {
  final UserProfile profile;
  final bool acceptBusy;
  final bool rejectBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FriendRequestTile({
    required this.profile,
    required this.acceptBusy,
    required this.rejectBusy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: appDivider),
      ),
      child: Row(
        children: [
          // Avatar
          _avatar(profile.username, profile.avatarUrl),
          const SizedBox(width: 10),

          // Nombre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'notifications.wants_friend'.tr(namedArgs: {'user': '${profile.username}'}),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11),
                ),
              ],
            ),
          ),

          // Botones
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: Icons.check_rounded,
                color: appSuccess,
                busy: acceptBusy,
                disabled: rejectBusy,
                onTap: onAccept,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.close_rounded,
                color: appError,
                busy: rejectBusy,
                disabled: acceptBusy,
                onTap: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tile: invitación a sala ───────────────────────────────────────────────────

class _RoomInvitationTile extends StatelessWidget {
  final RoomInvitation invitation;
  final bool joinBusy;
  final bool dismissBusy;
  final VoidCallback onJoin;
  final VoidCallback onDismiss;

  const _RoomInvitationTile({
    required this.invitation,
    required this.joinBusy,
    required this.dismissBusy,
    required this.onJoin,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: appDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: appAccentGlow,
                  borderRadius: BorderRadius.circular(radiusSm),
                ),
                child: const Icon(Icons.headphones_rounded,
                    color: appAccent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.roomName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        _avatar(invitation.senderName,
                            invitation.senderAvatar, radius: 8),
                        const SizedBox(width: 4),
                        Text(
                          'notifications.from_user'.tr(namedArgs: {'user': '${invitation.senderName}'}),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11),
                        ),
                        if (invitation.accessCode != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: appAccentGlow,
                              borderRadius:
                                  BorderRadius.circular(radiusFull),
                            ),
                            child: Text(
                              invitation.accessCode!,
                              style: const TextStyle(
                                color: appAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LoadingButton(
                  label: 'common.reject'.tr(),
                  busy: dismissBusy,
                  disabled: joinBusy,
                  outlined: true,
                  onTap: onDismiss,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LoadingButton(
                  label: 'Unirse',
                  icon: Icons.headphones_rounded,
                  busy: joinBusy,
                  disabled: dismissBusy,
                  onTap: onJoin,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tile: invitación a grupo ──────────────────────────────────────────────────

class _GroupInvitationTile extends StatelessWidget {
  final GroupInvitationModel invitation;
  final bool acceptBusy;
  final bool rejectBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _GroupInvitationTile({
    required this.invitation,
    required this.acceptBusy,
    required this.rejectBusy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: appDivider),
      ),
      child: Row(
        children: [
          GroupAvatar(
            name: invitation.groupName,
            photoUrl: invitation.groupPhotoUrl,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'notifications.invited_you'.tr(namedArgs: {'user': '${invitation.senderName}'}),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: Icons.check_rounded,
                color: appSuccess,
                busy: acceptBusy,
                disabled: rejectBusy,
                onTap: onAccept,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.close_rounded,
                color: appError,
                busy: rejectBusy,
                disabled: acceptBusy,
                onTap: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _avatar(String username, String? avatarUrl, {double radius = 18}) {
  return UserAvatar(username: username, avatarUrl: avatarUrl, radius: radius);
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final bool     busy;
  final bool     disabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radiusMd),
      child: InkWell(
        onTap: (busy || disabled) ? null : onTap,
        borderRadius: BorderRadius.circular(radiusMd),
        child: SizedBox(
          width: 34,
          height: 34,
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(9),
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: color),
                )
              : Icon(icon, color: disabled ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38) : color, size: 18),
        ),
      ),
    );
  }
}

class _LoadingButton extends StatelessWidget {
  final String    label;
  final IconData? icon;
  final bool      busy;
  final bool      disabled;
  final bool      outlined;
  final VoidCallback onTap;

  const _LoadingButton({
    required this.label,
    this.icon,
    required this.busy,
    required this.disabled,
    this.outlined = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          side: BorderSide(color: appDivider),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
          minimumSize: const Size(0, 36),
        ),
        onPressed: (busy || disabled) ? null : onTap,
        child: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)))
            : Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        backgroundColor: appAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
        minimumSize: const Size(0, 36),
      ),
      onPressed: (busy || disabled) ? null : onTap,
      icon: busy
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white))
          : (icon != null
              ? Icon(icon, size: 14)
              : const SizedBox.shrink()),
      label: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
