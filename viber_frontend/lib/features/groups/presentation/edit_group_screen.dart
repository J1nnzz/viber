import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import 'package:viber/core/widgets/image_crop.dart';
import '../infrastructure/group_service.dart';
import '../domain/group_models.dart';
import 'group_avatar.dart';

/// Edita la info de un grupo (nombre, descripción y foto). Devuelve el
/// [GroupModel] actualizado al guardar.
class EditGroupScreen extends StatefulWidget {
  final GroupModel group;
  const EditGroupScreen({super.key, required this.group});

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final _service  = GroupService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _photoUrl;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.group.name;
    _descCtrl.text = widget.group.description ?? '';
    _photoUrl      = widget.group.photoUrl;
  }

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
      if (mounted) AppSnackBar.show(context, e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'edit_room.name_empty_error'.tr()); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await _service.updateGroup(
        widget.group.id,
        name: name,
        description: _descCtrl.text.trim(),
        photoUrl: _photoUrl ?? '',
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
        title: Text('groups.edit_title'.tr()),
        actions: [
          TextButton(
            onPressed: (_saving || _uploading) ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: appAccent))
                : Text('common.save'.tr(),
                    style: TextStyle(color: appAccent, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          const SizedBox(width: spacingSm),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: 110, height: 110,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GroupAvatar(name: widget.group.name, photoUrl: _photoUrl, radius: 50),
                    Positioned(
                      bottom: 0, right: 0,
                      child: InkWell(
                        onTap: _uploading ? null : _pickPhoto,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: appAccent, shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                          child: _uploading
                              ? const Padding(padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: spacingXl),
            TextField(
              controller: _nameCtrl,
              maxLength: 80,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'groups.name_label'.tr(),
                prefixIcon: Icon(Icons.groups_rounded),
              ),
            ),
            const SizedBox(height: spacingMd),
            TextField(
              controller: _descCtrl,
              maxLength: 255,
              maxLines: 3,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'groups.description'.tr(),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: spacingMd),
              Text(_error!, style: const TextStyle(color: appError, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
