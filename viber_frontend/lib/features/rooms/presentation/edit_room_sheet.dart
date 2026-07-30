import 'package:flutter/material.dart';
import '../domain/room.dart';
import '../infrastructure/room_service.dart';
import 'package:viber/core/theme/app_theme.dart';

/// Bottom sheet de gestión de sala para el host.
/// Retorna el [Room] actualizado si se guardaron cambios, null si se canceló.
/// Si el host cierra la sala retorna la constante [EditRoomSheet.kClosed].
class EditRoomSheet extends StatefulWidget {
  static const kClosed = 'CLOSED';

  final Room room;
  const EditRoomSheet({super.key, required this.room});

  @override
  State<EditRoomSheet> createState() => _EditRoomSheetState();
}

class _EditRoomSheetState extends State<EditRoomSheet> {
  final _roomService = RoomService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _codeCtrl;

  late String _privacy;
  late Set<String> _selectedGenres;
  late int _maxParticipants;
  late bool _autoDj;

  bool _saving  = false;
  bool _closing = false;

  List<String> _availableGenres = [];
  bool _loadingGenres = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.room.name);
    _descCtrl = TextEditingController(text: widget.room.description ?? '');
    _codeCtrl = TextEditingController(text: widget.room.accessCode ?? '');
    _privacy  = widget.room.privacy.toUpperCase();
    _selectedGenres = Set.from(widget.room.genres);
    _maxParticipants = widget.room.maxParticipants ?? 50;
    _autoDj = widget.room.autoDj;
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final genres = await _roomService.fetchGenres();
    if (mounted) {
      setState(() {
        _availableGenres = genres;
        // Conservar los géneros ya seleccionados aunque no estén en el catálogo actual
        // (pueden existir de antes de que el admin los borrara)
        for (final g in widget.room.genres) {
          if (!_availableGenres.contains(g)) _availableGenres.add(g);
        }
        _loadingGenres = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('El nombre no puede estar vacío', color: appError);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await _roomService.updateRoom(
        roomId: widget.room.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        genres: _selectedGenres.toList(),
        privacy: _privacy,
        accessCode: _privacy == 'PRIVATE'
            ? (_codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim())
            : null,
        maxParticipants: _maxParticipants,
        autoDj: _autoDj,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), color: appError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmClose() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Cerrar la sala?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'Se expulsará a todos los oyentes y la sala dejará de existir.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sala',
                style: TextStyle(color: appError)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _closing = true);
    try {
      await _roomService.closeRoom(widget.room.id);
      if (mounted) Navigator.pop(context, EditRoomSheet.kClosed);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), color: appError);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      width: 320,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        border: Border(top: BorderSide(color: appAccent.withValues(alpha: 0.25))),
      ),
      padding: EdgeInsets.fromLTRB(spacingMd, spacingMd, spacingMd, spacingMd + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(radiusFull),
                ),
              ),
            ),
            const SizedBox(height: spacingMd),

            // Título
            Row(
              children: [
                const Icon(Icons.settings_rounded, color: appAccent, size: 18),
                const SizedBox(width: spacingSm),
                Expanded(
                  child: Text(
                    'Gestionar sala',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: spacingLg),

            // ── Nombre ────────────────────────────────────────────────────────
            _Label('Nombre de la sala'),
            const SizedBox(height: spacingXs),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Nombre de la sala',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
            ),
            const SizedBox(height: spacingMd),

            // ── Descripción ───────────────────────────────────────────────────
            _Label('Descripción (opcional)'),
            const SizedBox(height: spacingXs),
            TextField(
              controller: _descCtrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Describe tu sala…',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: spacingLg),

            // ── Géneros ───────────────────────────────────────────────────────
            Row(
              children: [
                _Label('Géneros'),
                if (_selectedGenres.isNotEmpty) ...[
                  const SizedBox(width: spacingXs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: appAccentGlow,
                      borderRadius: BorderRadius.circular(radiusFull),
                    ),
                    child: Text(
                      '${_selectedGenres.length}',
                      style: const TextStyle(
                          color: appAccent, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: spacingXs),
            if (_loadingGenres)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_availableGenres.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'El administrador aún no ha configurado géneros.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                ),
              )
            else
              Wrap(
                spacing: spacingXs,
                runSpacing: spacingXs,
                children: _availableGenres.map((g) {
                  final sel = _selectedGenres.contains(g);
                  return FilterChip(
                    label: Text(g),
                    selected: sel,
                    onSelected: (_) => setState(() {
                      sel ? _selectedGenres.remove(g) : _selectedGenres.add(g);
                    }),
                    selectedColor: appAccent.withOpacity(0.2),
                    checkmarkColor: appAccent,
                    labelStyle: TextStyle(
                      color: sel ? appAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: sel ? appAccent.withOpacity(0.5) : appAccent.withValues(alpha: 0.25),
                    ),
                    backgroundColor: context.appSurfaceAltColor,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            const SizedBox(height: spacingLg),

            // ── Máximo participantes ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Label('Máx. participantes'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: appAccentGlow,
                    borderRadius: BorderRadius.circular(radiusSm),
                  ),
                  child: Text(
                    '$_maxParticipants',
                    style: const TextStyle(
                      color: appAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: appAccent,
                inactiveTrackColor: appAccent.withValues(alpha: 0.25),
                thumbColor: appAccent,
                overlayColor: appAccent.withOpacity(0.15),
                trackHeight: 3,
              ),
              child: Slider(
                value: _maxParticipants.toDouble(),
                min: 2,
                max: 200,
                divisions: 99,
                onChanged: (v) => setState(() => _maxParticipants = v.round()),
              ),
            ),
            const SizedBox(height: spacingMd),

            // ── Privacidad ────────────────────────────────────────────────────
            _Label('Privacidad'),
            const SizedBox(height: spacingXs),
            Row(
              children: [
                Expanded(
                  child: _PrivacyToggle(
                    label: 'Pública',
                    icon: Icons.public_rounded,
                    description: 'Cualquiera puede unirse',
                    selected: _privacy == 'PUBLIC',
                    onTap: () => setState(() => _privacy = 'PUBLIC'),
                  ),
                ),
                const SizedBox(width: spacingMd),
                Expanded(
                  child: _PrivacyToggle(
                    label: 'Privada',
                    icon: Icons.lock_outlined,
                    description: 'Solo con código',
                    selected: _privacy == 'PRIVATE',
                    onTap: () => setState(() => _privacy = 'PRIVATE'),
                  ),
                ),
              ],
            ),

            if (_privacy == 'PRIVATE') ...[
              const SizedBox(height: spacingMd),
              TextField(
                controller: _codeCtrl,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: widget.room.accessCode != null
                      ? 'Actual: ${widget.room.accessCode} (vacío = mantener)'
                      : 'Código (vacío = auto-generar)',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                ),
              ),
            ],

            const SizedBox(height: spacingLg),

            // ── Sala permanente (auto-DJ) ─────────────────────────────────────
            _Label('Sala permanente'),
            const SizedBox(height: spacingXs),
            Material(
              color: _autoDj ? appAccentGlow : context.appSurfaceAltColor,
              borderRadius: BorderRadius.circular(radiusMd),
              child: InkWell(
                onTap: () => setState(() => _autoDj = !_autoDj),
                borderRadius: BorderRadius.circular(radiusMd),
                child: Container(
                  padding: const EdgeInsets.all(spacingMd),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border.all(
                      color: _autoDj ? appAccent.withOpacity(0.5) : appAccent.withValues(alpha: 0.25),
                      width: _autoDj ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_mode_rounded,
                          color: _autoDj ? appAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          size: 18),
                      const SizedBox(width: spacingSm),
                      Expanded(
                        child: Text(
                          'Auto-DJ: añade canciones del mismo estilo cuando la cola se queda corta.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Switch(
                        value: _autoDj,
                        activeColor: appAccent,
                        onChanged: (v) => setState(() => _autoDj = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: spacingXl),

            // ── Botón guardar ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                onPressed: _saving || _closing ? null : _save,
              ),
            ),

            const SizedBox(height: spacingMd),

            // ── Separador ─────────────────────────────────────────────────────
            Divider(color: appAccent.withValues(alpha: 0.2)),
            const SizedBox(height: spacingXs),

            // ── Zona peligrosa: cerrar sala ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: appError,
                  side: const BorderSide(color: appError),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radiusMd)),
                ),
                icon: _closing
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: appError))
                    : const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(_closing ? 'Cerrando…' : 'Cerrar sala permanentemente'),
                onPressed: _saving || _closing ? null : _confirmClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
}

class _PrivacyToggle extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PrivacyToggle({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? appAccentGlow : context.appSurfaceAltColor,
      borderRadius: BorderRadius.circular(radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusMd),
        child: Container(
          padding: const EdgeInsets.all(spacingMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(
              color: selected ? appAccent.withOpacity(0.5) : appAccent.withValues(alpha: 0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? appAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 18),
              const SizedBox(height: spacingXs),
              Text(
                label,
                style: TextStyle(
                  color: selected ? appAccent : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: selected ? appAccent.withOpacity(0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
