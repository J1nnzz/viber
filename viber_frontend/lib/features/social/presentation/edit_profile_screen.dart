import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/image_crop.dart';
import '../infrastructure/friendship_service.dart';
import '../domain/user_profile.dart';

/// Pantalla de edición del perfil propio: username, nombre visible, bio y avatar.
/// La imagen se sube a Cloudinary desde el navegador (dart:html FileReader en web)
/// y se guarda la URL resultante en el perfil.
class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _service         = FriendshipService();
  final _usernameCtrl    = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl         = TextEditingController();

  bool    _saving       = false;
  bool    _uploadingImg = false;
  String? _error;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.text    = widget.profile.username;
    _displayNameCtrl.text = widget.profile.displayName ?? '';
    _bioCtrl.text         = widget.profile.bio         ?? '';
    _avatarUrl            = widget.profile.avatarUrl;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ── Seleccionar y subir imagen ─────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final cropped = await pickAndCropImage(
      context,
      circle: true,
      title: 'edit_profile.adjust_photo'.tr(),
    );
    if (cropped == null) return;

    setState(() => _uploadingImg = true);
    try {
      final url = await _service.uploadAvatar(cropped.bytes, cropped.name);
      setState(() => _avatarUrl = url);
      if (mounted) AppSnackBar.show(context, 'edit_profile.avatar_updated'.tr());
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          'errors.image_upload_detail'.tr(namedArgs: {
            'error': e.toString().replaceAll('Exception: ', ''),
          }),
          error: true);
    } finally {
      setState(() => _uploadingImg = false);
    }
  }

  // ── Guardar cambios ────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await _service.updateMe(
        username:    _usernameCtrl.text.trim(),
        displayName: _displayNameCtrl.text.trim().isEmpty
            ? null : _displayNameCtrl.text.trim(),
        bio:         _bioCtrl.text.trim().isEmpty
            ? null : _bioCtrl.text.trim(),
        avatarUrl:   _avatarUrl,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('profile.edit_button'.tr()),
        actions: [
          TextButton(
            onPressed: (_saving || _uploadingImg) ? null : _save,
            child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: appAccent))
              : Text('common.save'.tr(),
                  style: TextStyle(
                    color: appAccent, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const SizedBox(width: spacingSm),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Avatar ────────────────────────────────────────────────────────
            Center(
              child: SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildAvatarPreview(),
                    Positioned(
                      bottom: 0, right: 0,
                      child: InkWell(
                        onTap: _uploadingImg ? null : _pickAndUpload,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: appAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                width: 2),
                          ),
                          child: _uploadingImg
                            ? const Padding(
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt_rounded,
                                size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: spacingXl),

            // ── Username ──────────────────────────────────────────────────────
            _buildLabel('edit_profile.username_label'.tr()),
            const SizedBox(height: spacingXs),
            TextField(
              controller: _usernameCtrl,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'edit_profile.username_hint'.tr(),
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                helperText:
                    'edit_profile.username_helper'.tr(),
                helperStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11),
              ),
            ),
            const SizedBox(height: spacingLg),

            // ── Nombre visible ────────────────────────────────────────────────
            _buildLabel('edit_profile.display_name_label'.tr()),
            const SizedBox(height: spacingXs),
            TextField(
              controller: _displayNameCtrl,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'edit_profile.name_hint'.tr(),
                prefixIcon: const Icon(Icons.person_rounded),
                helperText: 'edit_profile.name_rule'.tr(),
                helperStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11),
              ),
            ),
            const SizedBox(height: spacingLg),

            // ── Bio ───────────────────────────────────────────────────────────
            _buildLabel('Bio'),
            const SizedBox(height: spacingXs),
            TextField(
              controller: _bioCtrl,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              maxLength: 150,
              maxLines:  3,
              decoration: InputDecoration(
                hintText: 'edit_profile.bio_hint'.tr(),
                alignLabelWithHint: true,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: spacingMd),
              Container(
                padding: const EdgeInsets.all(spacingMd),
                decoration: BoxDecoration(
                  color: appError.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(radiusMd),
                  border: Border.all(color: appError.withOpacity(0.3)),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: appError, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ));

  Widget _buildAvatarPreview() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: appAccentGlow,
      backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
          ? NetworkImage(_avatarUrl!) : null,
      onBackgroundImageError:
          _avatarUrl != null ? (_, __) {} : null,
      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
        ? Text(
            widget.profile.username.isNotEmpty
                ? widget.profile.username[0].toUpperCase() : '?',
            style: const TextStyle(
                color: appAccent, fontSize: 36, fontWeight: FontWeight.w700))
        : null,
    );
  }
}
