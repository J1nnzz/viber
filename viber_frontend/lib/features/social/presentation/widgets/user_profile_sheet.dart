import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';
import 'package:viber/core/widgets/user_avatar.dart';
import '../../infrastructure/friendship_service.dart';
import '../../domain/user_profile.dart';
import '../profile_screen.dart';

/// Muestra el mini-perfil de un usuario en un bottom sheet.
/// [username] = usuario a mostrar. [myUsername] = usuario autenticado.
Future<void> showUserProfileSheet(
  BuildContext context, {
  required String username,
  required String myUsername,
}) {
  if (username == myUsername) return Future.value();
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _UserProfileSheet(
      username:   username,
      myUsername: myUsername,
    ),
  );
}

class _UserProfileSheet extends StatefulWidget {
  final String username;
  final String myUsername;

  const _UserProfileSheet({
    required this.username,
    required this.myUsername,
  });

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  final _service = FriendshipService();
  UserProfile? _profile;
  bool _loading = true;
  bool _acting  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await _service.getProfile(widget.username);
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest() async {
    setState(() => _acting = true);
    try {
      await _service.sendRequest(widget.username);
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => _acting = true);
    try {
      await _service.acceptRequest(widget.username);
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _removeFriend() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('profile.delete_friend'.tr(),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('profile.delete_friend_confirm'.tr(namedArgs: {'user': '${widget.username}'}),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('common.cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('common.delete'.tr(),
                  style: TextStyle(color: appError))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _acting = true);
    try {
      await _service.removeFriend(widget.username);
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? appError : Theme.of(context).colorScheme.surface,
      behavior: SnackBarBehavior.floating,
      width: 320,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd)),
    ));
  }

  void _openFullProfile() {
    Navigator.pop(context);
    Navigator.push(
      context,
      fadeThroughRoute(ProfileScreen(username: widget.username)),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(spacingXl, spacingMd, spacingXl, spacingXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: spacingLg),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: spacingXl),
              child: CircularProgressIndicator(
                  color: appAccent, strokeWidth: 2),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: spacingXl),
              child: Text(_error!,
                  style: const TextStyle(color: appError, fontSize: 13)),
            )
          else if (_profile != null)
            _buildContent(_profile!),
        ],
      ),
    );
  }

  Widget _buildContent(UserProfile p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        _buildAvatar(p, radius: 36),
        const SizedBox(height: spacingMd),

        // Nombre
        Text(
          p.displayLabel,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '@${p.username}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
        ),

        // Bio
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          const SizedBox(height: spacingSm),
          Text(
            p.bio!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.45,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: spacingSm),

        // Amigos count
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 14),
            const SizedBox(width: 4),
            Text(
              'profile.friends_count'.plural(p.friendCount),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 12),
            ),
          ],
        ),

        const SizedBox(height: spacingLg),

        // Botón de amistad
        SizedBox(
          width: double.infinity,
          child: _buildFriendButton(p),
        ),

        const SizedBox(height: spacingSm),

        // Ver perfil completo
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.person_outline, size: 16),
            label: Text('profile.view_full'.tr()),
            onPressed: _openFullProfile,
          ),
        ),
      ],
    );
  }

  Widget _buildFriendButton(UserProfile p) {
    if (_acting) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              color: appAccent, strokeWidth: 2),
        ),
      );
    }
    return switch (p.relation) {
      'FRIENDS' => OutlinedButton.icon(
          icon: const Icon(Icons.person_remove_outlined, size: 16),
          label: Text('profile.delete_friend'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: appError,
            side: const BorderSide(color: appError),
          ),
          onPressed: _removeFriend,
        ),
      'PENDING_SENT' => OutlinedButton.icon(
          icon: const Icon(Icons.hourglass_top_rounded, size: 16),
          label: Text('profile.request_sent'.tr()),
          onPressed: null,
        ),
      'PENDING_RECEIVED' => ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16),
          label: Text('profile.accept_request'.tr()),
          onPressed: _acceptRequest,
        ),
      _ => ElevatedButton.icon(
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: Text('profile.add_friend'.tr()),
          onPressed: _sendRequest,
        ),
    };
  }

  Widget _buildAvatar(UserProfile p, {required double radius}) {
    return UserAvatar(username: p.username, avatarUrl: p.avatarUrl, radius: radius);
  }
}
