import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/image_crop.dart';
import '../infrastructure/group_service.dart';
import '../domain/group_models.dart';

/// Formulario para crear un grupo: nombre (obligatorio), foto y descripción.
/// Devuelve el [GroupModel] creado al hacer pop.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _service     = GroupService();
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();

  String? _photoUrl;
  bool _uploading = false;
  bool _creating  = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final cropped = await pickAndCropImage(
      context,
      circle: true,
      title: 'groups.adjust_photo'.tr(),
    );
    if (cropped == null) return;

    setState(() => _uploading = true);
    try {
      final url = await _service.uploadGroupPhoto(cropped.bytes, cropped.name);
      setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) AppSnackBar.show(context,
          e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'groups.name_required'.tr());
      return;
    }
    setState(() { _creating = true; _error = null; });
    try {
      final group = await _service.createGroup(
        name:        name,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        photoUrl:    _photoUrl,
      );
      if (mounted) Navigator.pop(context, group);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('groups.new_group'.tr()),
        actions: [
          TextButton(
            onPressed: (_creating || _uploading) ? null : _create,
            child: _creating
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: appAccent))
                : Text('groups.create'.tr(),
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
            // ── Foto del grupo ────────────────────────────────────────────────
            Center(
              child: SizedBox(
                width: 110, height: 110,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildPhotoPreview(),
                    Positioned(
                      bottom: 0, right: 0,
                      child: InkWell(
                        onTap: _uploading ? null : _pickPhoto,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: appAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                          child: _uploading
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

            _label('groups.name_label'.tr()),
            const SizedBox(height: spacingXs),
            TextField(
              controller: _nameCtrl,
              maxLength: 80,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'groups.name_hint'.tr(),
                prefixIcon: Icon(Icons.groups_rounded),
              ),
            ),
            const SizedBox(height: spacingMd),

            _label('create_room.description_label'.tr()),
            const SizedBox(height: spacingXs),
            TextField(
              controller: _descCtrl,
              maxLength: 255,
              maxLines: 3,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'groups.desc_hint'.tr(),
                alignLabelWithHint: true,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: spacingMd),
              Container(
                padding: const EdgeInsets.all(spacingMd),
                decoration: BoxDecoration(
                  color: appError.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radiusMd),
                  border: Border.all(color: appError.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: appError, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: 12, fontWeight: FontWeight.w500,
      ));

  Widget _buildPhotoPreview() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: appAccentGlow,
      backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
          ? NetworkImage(_photoUrl!) : null,
      child: (_photoUrl == null || _photoUrl!.isEmpty)
          ? const Icon(Icons.groups_rounded, color: appAccent, size: 40)
          : null,
    );
  }
}
