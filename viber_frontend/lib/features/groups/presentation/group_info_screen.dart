import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../../auth/infrastructure/auth_service.dart';
import '../../social/domain/user_profile.dart';
import '../../social/infrastructure/friendship_service.dart';
import '../domain/group_models.dart';
import '../infrastructure/group_service.dart';
import 'group_avatar.dart';
import 'edit_group_screen.dart';

/// Información y administración de un grupo: miembros, roles, permisos
/// granulares, invitaciones y acciones de salida/borrado.
///
/// Devuelve por pop: 'left' / 'deleted' si el usuario abandona/borra el grupo,
/// o el [GroupModel] actualizado si solo cambió la info.
class GroupInfoScreen extends StatefulWidget {
  final int groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _service = GroupService();
  final _friendshipService = FriendshipService();
  final _auth = AuthService();

  GroupModel? _group;
  String? _myUsername;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final token = await _auth.getToken();
    if (token != null) {
      final parts   = token.split('.');
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      _myUsername   = (jsonDecode(decoded) as Map<String, dynamic>)['sub'] as String?;
    }
    await _reload();
  }

  Future<void> _reload() async {
    try {
      final g = await _service.getGroup(widget.groupId);
      if (mounted) setState(() { _group = g; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackBar.show(context, e.toString().replaceAll('Exception: ', ''), error: true);
      }
    }
  }

  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _reload();
      if (ok != null && mounted) AppSnackBar.show(context, ok);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Acciones ────────────────────────────────────────────────────────────────

  Future<void> _edit() async {
    final updated = await Navigator.push<GroupModel>(
      context, MaterialPageRoute(builder: (_) => EditGroupScreen(group: _group!)));
    if (updated != null && mounted) setState(() => _group = updated);
  }

  Future<void> _invite() async {
    final friends = await _friendshipService.getFriends().catchError((_) => <UserProfile>[]);
    if (!mounted) return;
    final memberUsernames = _group!.members.map((m) => m.username).toSet();
    final invitable = friends.where((f) => !memberUsernames.contains(f.username)).toList();

    final picked = await showModalBottomSheet<UserProfile>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvitePicker(friends: invitable),
    );
    if (picked == null) return;
    await _run(() => _service.invite(_group!.id, picked.username),
        ok: 'groups.invite_sent_to'.tr(namedArgs: {'user': '${picked.username}'}));
  }

  Future<void> _confirm(String title, String message, String confirmLabel,
      {bool danger = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: TextStyle(color: danger ? appError : appAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (result == true) _pendingConfirm = true; else _pendingConfirm = false;
  }

  bool _pendingConfirm = false;

  Future<void> _leave() async {
    await _confirm('groups.leave_group'.tr(), 'groups.leave_confirm'.tr(namedArgs: {'name': '${_group!.name}'}), 'Salir', danger: true);
    if (!_pendingConfirm) return;
    try {
      await _service.leave(_group!.id);
      if (mounted) Navigator.pop(context, 'left');
    } catch (e) {
      if (mounted) AppSnackBar.show(context, e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _delete() async {
    await _confirm('Borrar grupo', 'groups.delete_confirm'.tr(namedArgs: {'name': '${_group!.name}'}), 'Borrar', danger: true);
    if (!_pendingConfirm) return;
    try {
      await _service.deleteGroup(_group!.id);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      if (mounted) AppSnackBar.show(context, e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('groups.info_title'.tr())),
      body: _loading || _group == null
          ? const Center(child: CircularProgressIndicator(color: appAccent))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: spacingLg),
              children: [
                _header(),
                const SizedBox(height: spacingLg),
                if (_group!.can(_group!.invitePolicy)) _inviteButton(),
                if (_group!.isAdmin) ...[
                  const SizedBox(height: spacingLg),
                  _permissionsSection(),
                ],
                const SizedBox(height: spacingLg),
                _membersSection(),
                const SizedBox(height: spacingLg),
                _dangerZone(),
              ],
            ),
    );
  }

  Widget _header() {
    final g = _group!;
    return Column(
      children: [
        GroupAvatar(name: g.name, photoUrl: g.photoUrl, radius: 48),
        const SizedBox(height: spacingMd),
        Text(g.name,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20, fontWeight: FontWeight.w700)),
        if (g.description != null && g.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: spacingLg),
            child: Text(g.description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13, height: 1.4)),
          ),
        ],
        const SizedBox(height: 6),
        Text('groups.members_count'.tr(namedArgs: {'n': '${g.memberCount}'}),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12)),
        if (g.can(g.editInfoPolicy)) ...[
          const SizedBox(height: spacingMd),
          OutlinedButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text('common.edit'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: appAccent,
              side: const BorderSide(color: appAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _inviteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacingMd),
      child: ElevatedButton.icon(
        onPressed: _busy ? null : _invite,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: Text('room.invite_friends_section'.tr()),
        style: ElevatedButton.styleFrom(
          backgroundColor: appAccent, foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),
    );
  }

  // ── Permisos ──────────────────────────────────────────────────────────────

  Widget _permissionsSection() {
    final g = _group!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('PERMISOS'),
        _permissionRow('Invitar miembros', g.invitePolicy,
            (p) => _service.updatePermissions(g.id, invitePolicy: p)),
        _permissionRow('groups.edit_info'.tr(), g.editInfoPolicy,
            (p) => _service.updatePermissions(g.id, editInfoPolicy: p)),
        _permissionRow('Enviar mensajes', g.sendMessagePolicy,
            (p) => _service.updatePermissions(g.id, sendMessagePolicy: p)),
        _permissionRow('Lanzar quiz', g.startQuizPolicy,
            (p) => _service.updatePermissions(g.id, startQuizPolicy: p)),
      ],
    );
  }

  Widget _permissionRow(String label, GroupPermission value,
      Future<GroupModel> Function(GroupPermission) update) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(spacingMd, 4, spacingMd, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
          ),
          _permToggle(value, (p) => _run(() async { await update(p); })),
        ],
      ),
    );
  }

  Widget _permToggle(GroupPermission value, ValueChanged<GroupPermission> onChanged) {
    Widget seg(String text, GroupPermission p) {
      final selected = value == p;
      return InkWell(
        onTap: _busy || selected ? null : () => onChanged(p),
        borderRadius: BorderRadius.circular(radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? appAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          child: Text(text,
              style: TextStyle(
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radiusSm),
        border: Border.all(color: appDivider),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('Todos', GroupPermission.allMembers),
        seg('Admins', GroupPermission.adminsOnly),
      ]),
    );
  }

  // ── Miembros ──────────────────────────────────────────────────────────────

  Widget _membersSection() {
    final g = _group!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('MIEMBROS (${g.members.length})'),
        ...g.members.map(_memberTile),
      ],
    );
  }

  Widget _memberTile(GroupMemberModel m) {
    final g = _group!;
    final isMe = m.username == _myUsername;
    final canManage = g.isAdmin && !isMe;

    return ListTile(
      leading: UserAvatar(username: m.username, avatarUrl: m.avatarUrl, radius: 20),
      title: Text(isMe ? 'groups.member_you'.tr(namedArgs: {'name': '${m.displayLabel}'}) : m.displayLabel,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text('@${m.username} · ${m.role.label}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
      trailing: canManage ? _memberMenu(m) : _roleBadge(m.role),
    );
  }

  Widget _roleBadge(GroupRole role) {
    if (role == GroupRole.member) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: appAccentGlow,
        borderRadius: BorderRadius.circular(radiusFull),
      ),
      child: Text(role == GroupRole.owner ? 'Propietario' : 'Admin',
          style: const TextStyle(color: appAccent, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _memberMenu(GroupMemberModel m) {
    final g = _group!;
    final iAmOwner = g.isOwner;
    final canKick = m.role != GroupRole.owner && g.myRole.rank > m.role.rank;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      onSelected: (value) {
        switch (value) {
          case 'promote':
            _run(() => _service.changeRole(g.id, m.username, GroupRole.admin),
                ok: 'groups.now_admin'.tr(namedArgs: {'user': '${m.username}'}));
            break;
          case 'demote':
            _run(() => _service.changeRole(g.id, m.username, GroupRole.member),
                ok: 'groups.no_longer_admin'.tr(namedArgs: {'user': '${m.username}'}));
            break;
          case 'transfer':
            _confirmTransfer(m);
            break;
          case 'kick':
            _run(() => _service.kick(g.id, m.username), ok: '@${m.username} expulsado');
            break;
        }
      },
      itemBuilder: (_) => [
        if (iAmOwner && m.role == GroupRole.member)
          PopupMenuItem(value: 'promote', child: Text('groups.make_admin'.tr())),
        if (iAmOwner && m.role == GroupRole.admin)
          PopupMenuItem(value: 'demote', child: Text('groups.remove_admin'.tr())),
        if (iAmOwner)
          PopupMenuItem(value: 'transfer', child: Text('groups.transfer_ownership'.tr())),
        if (canKick)
          PopupMenuItem(value: 'kick',
              child: Text('groups.kick'.tr(), style: TextStyle(color: appError))),
      ],
    );
  }

  Future<void> _confirmTransfer(GroupMemberModel m) async {
    await _confirm('groups.transfer_ownership'.tr(),
        'groups.transfer_confirm'.tr(namedArgs: {'user': '${m.username}'}),
        'Transferir');
    if (!_pendingConfirm) return;
    await _run(() => _service.transferOwnership(_group!.id, m.username),
        ok: 'Propiedad transferida a @${m.username}');
  }

  // ── Zona peligrosa ──────────────────────────────────────────────────────────

  Widget _dangerZone() {
    final g = _group!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacingMd),
      child: Column(
        children: [
          if (g.isOwner)
            _dangerButton('Borrar grupo', Icons.delete_outline_rounded, _delete)
          else
            _dangerButton('groups.leave_group'.tr(), Icons.logout_rounded, _leave),
          if (g.isOwner && g.memberCount > 1) ...[
            const SizedBox(height: 6),
            Text('groups.transfer_first'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _dangerButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: appError,
        side: BorderSide(color: appError.withValues(alpha: 0.5)),
        minimumSize: const Size(double.infinity, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(spacingMd, 4, spacingMd, 8),
      child: Text(label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
    );
  }
}

// ── Selector de amigo a invitar ─────────────────────────────────────────────

class _InvitePicker extends StatelessWidget {
  final List<UserProfile> friends;
  const _InvitePicker({required this.friends});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(0, 14, 0, bottomPad + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.person_add_alt_1_rounded, color: appAccent, size: 20),
              const SizedBox(width: 8),
              Text('groups.invite_friend'.tr(),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('groups.no_friends_invite'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: friends.map((f) => ListTile(
                  leading: UserAvatar(username: f.username, avatarUrl: f.avatarUrl, radius: 18),
                  title: Text(f.displayLabel,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                  subtitle: Text('@${f.username}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                  onTap: () => Navigator.pop(context, f),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
