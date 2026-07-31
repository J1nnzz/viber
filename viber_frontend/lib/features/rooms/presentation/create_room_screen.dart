import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../infrastructure/room_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/image_crop.dart';

/// Pantalla de creación de una nueva sala de música.
/// Permite configurar nombre, descripción, géneros, privacidad (PUBLIC/PRIVATE),
/// código de acceso (solo para privadas) y aforo máximo.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _codeController = TextEditingController();
  final _welcomeController = TextEditingController();
  final _roomService = RoomService();

  String _privacy = 'PUBLIC';
  final Set<String> _selectedGenres = {};
  int _maxParticipants = 50;
  bool _autoDj = false;
  bool _isLoading = false;

  // Personalización
  String? _coverUrl;
  bool _uploadingCover = false;
  String? _accentColor; // hex "#RRGGBB"; null = acento por defecto de la app

  // Paleta de colores de acento disponibles
  static const _accentPalette = <String>[
    '#7C4DFF', '#FF5252', '#FF9800', '#FFC107',
    '#4CAF50', '#00BCD4', '#2196F3', '#E91E63',
  ];

  List<String> _availableGenres = [];
  bool _loadingGenres = true;

  @override
  void initState() {
    super.initState();
    _loadGenres();
    // Refresca el preview de la portada al escribir el nombre.
    _nameController.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _codeController.dispose();
    _welcomeController.dispose();
    super.dispose();
  }

  // Color de acento efectivo (el elegido o el de la app por defecto).
  Color get _effectiveAccent =>
      _accentColor != null ? _hexToColor(_accentColor!) : appAccent;

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  // ── Portada ────────────────────────────────────────────────────────────────
  Future<void> _pickCover() async {
    final cropped = await pickAndCropImage(
      context,
      aspectRatio: 16 / 9,
      title: 'Ajustar portada',
    );
    if (cropped == null) return;

    setState(() => _uploadingCover = true);
    try {
      final url = await _roomService.uploadRoomCover(cropped.bytes, cropped.name);
      if (mounted) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _loadGenres() async {
    final genres = await _roomService.fetchGenres();
    if (mounted) setState(() { _availableGenres = genres; _loadingGenres = false; });
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('create_room.name_required'.tr())),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final welcome = _welcomeController.text.trim();
      final room = await _roomService.createRoom(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        genres: _selectedGenres.toList(),
        privacy: _privacy,
        accessCode:
            _privacy == 'PRIVATE' ? _codeController.text.trim() : null,
        maxParticipants: _maxParticipants,
        autoDj: _autoDj,
        coverImageUrl: _coverUrl,
        accentColor: _accentColor,
        welcomeMessage: welcome.isEmpty ? null : welcome,
      );
      if (mounted) Navigator.pop(context, room);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Widgets de personalización ──────────────────────────────────────────────

  Widget _buildCoverPicker() {
    final name = _nameController.text.trim();
    return GestureDetector(
      onTap: _uploadingCover ? null : _pickCover,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusMd),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fondo: portada o degradado con el color de acento
              if (_coverUrl != null)
                Image.network(_coverUrl!, fit: BoxFit.cover)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _effectiveAccent.withValues(alpha: 0.85),
                        _effectiveAccent.withValues(alpha: 0.40),
                      ],
                    ),
                  ),
                ),
              // Velo inferior para legibilidad
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              // Nombre en vivo
              Positioned(
                left: spacingMd,
                right: spacingMd,
                bottom: spacingMd,
                child: Text(
                  name.isEmpty ? 'create_room.your_room'.tr() : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
              ),
              // Botón cámara / spinner
              Positioned(
                top: spacingSm,
                right: spacingSm,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: _uploadingCover
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
              // Quitar portada
              if (_coverUrl != null && !_uploadingCover)
                Positioned(
                  top: spacingSm,
                  left: spacingSm,
                  child: GestureDetector(
                    onTap: () => setState(() => _coverUrl = null),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccentSelector() {
    return Wrap(
      spacing: spacingSm,
      runSpacing: spacingSm,
      children: [
        _accentDot(null), // por defecto (acento de la app)
        ..._accentPalette.map(_accentDot),
      ],
    );
  }

  Widget _accentDot(String? hex) {
    final selected = _accentColor == hex;
    final color = hex == null ? appAccent : _hexToColor(hex);
    return GestureDetector(
      onTap: () => setState(() => _accentColor = hex),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : (hex == null
                ? const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 15)
                : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('create_room.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Portada + preview en vivo ─────────────────────────────
            _buildCoverPicker(),
            const SizedBox(height: spacingLg),

            // ── Nombre ────────────────────────────────────────────────
            AppTextField(
              controller: _nameController,
              label: 'create_room.name_label'.tr(),
              prefixIcon: Icons.meeting_room_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: spacingMd),

            // ── Descripción ───────────────────────────────────────────
            AppTextField(
              controller: _descController,
              label: 'create_room.description_label'.tr(),
              prefixIcon: Icons.description_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: spacingMd),

            // ── Mensaje de bienvenida ─────────────────────────────────
            AppTextField(
              controller: _welcomeController,
              label: 'Mensaje de bienvenida (opcional)',
              prefixIcon: Icons.waving_hand_outlined,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: spacingXs),
            Text(
              'create_room.welcome_hint'.tr(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: spacingLg),

            // ── Géneros (multi-select) ─────────────────────────────────
            Row(
              children: [
                Text('create_room.genres_label'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: spacingSm),
                if (_selectedGenres.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: appAccentGlow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_selectedGenres.length}',
                      style: const TextStyle(
                        color: appAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: spacingSm),
            if (_loadingGenres)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_availableGenres.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('create_room.no_genres'.tr(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                ),
              )
            else
              Wrap(
                spacing: spacingSm,
                runSpacing: spacingSm,
                children: _availableGenres.map((g) {
                  final selected = _selectedGenres.contains(g);
                  return FilterChip(
                    label: Text(g),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      selected ? _selectedGenres.remove(g) : _selectedGenres.add(g);
                    }),
                    selectedColor: appAccent.withOpacity(0.2),
                    checkmarkColor: appAccent,
                    labelStyle: TextStyle(
                      color: selected ? appAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: selected ? appAccent.withOpacity(0.5) : appDivider,
                    ),
                    backgroundColor: context.appSurfaceAltColor,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  );
                }).toList(),
              ),
            const SizedBox(height: spacingLg),

            // ── Color de acento ───────────────────────────────────────
            Text(
              'create_room.accent_color'.tr(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: spacingSm),
            _buildAccentSelector(),
            const SizedBox(height: spacingLg),

            // ── Máximo de participantes ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('create_room.max_participants_label'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
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
            const SizedBox(height: spacingXs),
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
                onChanged: (v) =>
                    setState(() => _maxParticipants = v.round()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('2', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11)),
                Text('200', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
            const SizedBox(height: spacingLg),

            // ── Privacidad ─────────────────────────────────────────────
            Text('settings.privacy_section'.tr(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: spacingSm),
            Row(
              children: [
                Expanded(
                  child: _PrivacyOption(
                    label: 'create_room.public'.tr(),
                    icon: Icons.public_rounded,
                    description: 'create_room.public_desc'.tr(),
                    selected: _privacy == 'PUBLIC',
                    onTap: () => setState(() => _privacy = 'PUBLIC'),
                  ),
                ),
                const SizedBox(width: spacingMd),
                Expanded(
                  child: _PrivacyOption(
                    label: 'Privada',
                    icon: Icons.lock_outlined,
                    description: 'create_room.private_desc'.tr(),
                    selected: _privacy == 'PRIVATE',
                    onTap: () => setState(() => _privacy = 'PRIVATE'),
                  ),
                ),
              ],
            ),

            // ── Código de acceso (solo privada) ───────────────────────
            if (_privacy == 'PRIVATE') ...[
              const SizedBox(height: spacingMd),
              AppTextField(
                controller: _codeController,
                label: 'create_room.access_code_label'.tr(),
                prefixIcon: Icons.vpn_key_outlined,
                textInputAction: TextInputAction.done,
              ),
            ],

            const SizedBox(height: spacingLg),

            // ── Sala permanente (auto-DJ) ─────────────────────────────
            Material(
              color: _autoDj ? appAccentGlow : context.appSurfaceAltColor,
              borderRadius: BorderRadius.circular(radiusMd),
              child: InkWell(
                onTap: () => setState(() => _autoDj = !_autoDj),
                borderRadius: BorderRadius.circular(radiusMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: spacingMd, vertical: spacingMd),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border.all(
                      color: _autoDj ? appAccent.withOpacity(0.5) : appDivider,
                      width: _autoDj ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_mode_rounded,
                        color: _autoDj
                            ? appAccent
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      const SizedBox(width: spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'create_room.permanent'.tr(),
                              style: TextStyle(
                                color: _autoDj
                                    ? appAccent
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'create_room.autodj_desc'.tr(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: spacingSm),
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

            // ── Botón crear ───────────────────────────────────────────
            AppPrimaryButton(
              label: 'create_room.create_button'.tr(),
              icon: Icons.add_rounded,
              isLoading: _isLoading,
              onPressed: _create,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PrivacyOption({
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
          padding: const EdgeInsets.symmetric(
              horizontal: spacingMd, vertical: spacingMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(
              color: selected ? appAccent.withOpacity(0.5) : appDivider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? appAccent : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
              const SizedBox(height: spacingSm),
              Text(
                label,
                style: TextStyle(
                  color: selected ? appAccent : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: selected
                      ? appAccent.withOpacity(0.7)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
