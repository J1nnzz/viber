import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../domain/room.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/app_image.dart';
import 'package:viber/core/widgets/motion.dart';

/// Paleta de color por género: cada sala recibe un color estable (hash del
/// género o, si no tiene, del nombre). Vibrante y alineada a marca — sin el
/// índigo antiguo. Se usa en el fondo de las tarjetas, la miniatura y las tags.
const List<Color> kRoomGenreColors = [
  Color(0xFF9B6DD2), // morado
  Color(0xFFE0534A), // rojo-coral
  Color(0xFF2FA98D), // teal
  Color(0xFFE08C3A), // ámbar
  Color(0xFFD65A9A), // magenta
  Color(0xFF4A8FD6), // azul
];

// ── Featured Card (carrusel horizontal) ──────────────────────────────────────

class RoomFeaturedCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  /// Si se pasa, se muestra el menú de gestión (solo para el host)
  final void Function(Room)? onEdit;
  final void Function(Room)? onClose;

  const RoomFeaturedCard({
    super.key,
    required this.room,
    required this.onTap,
    this.onEdit,
    this.onClose,
  });

  Color _genreColor() {
    const colors = kRoomGenreColors;
    if (room.genres.isEmpty) return colors[0];
    return colors[room.genres.first.hashCode.abs() % colors.length];
  }

  /// Fondo de la tarjeta: portada de la sala si la hay, si no la carátula de lo
  /// que suena, y como último recurso un color sólido.
  Widget _background(Color accent) {
    final cover = room.coverImageUrl;
    if (cover != null && cover.isNotEmpty) {
      return AppImage(
        url: cover,
        fit: BoxFit.cover,
        errorBuilder: (_) => _ColorBackground(accent: accent),
      );
    }
    if (room.currentVideoThumbnail != null) {
      return AppImage(
        url: room.currentVideoThumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (_) => _ColorBackground(accent: accent),
      );
    }
    return _ColorBackground(accent: accent);
  }

  @override
  Widget build(BuildContext context) {
    final accent = hexToColorOrNull(room.accentColor) ?? _genreColor();

    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: appDivider),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo: portada / carátula / color
            _background(accent),

            // Degradado oscuro
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.all(spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior: oyentes + menú host
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.headphones_rounded,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              '${room.listenerCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (room.listenerCount > 0) ...[
                        const SizedBox(width: spacingXs),
                        const LiveDot(size: 6),
                      ],
                      const Spacer(),
                      // Menú del host
                      if (onEdit != null || onClose != null)
                        _HostMenuButton(
                          room: room,
                          onEdit: onEdit,
                          onClose: onClose,
                          dark: true,
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Género pill
                  if (room.genres.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(radiusFull),
                      ),
                      child: Text(
                        room.genres.first,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  const SizedBox(height: spacingXs),

                  // Nombre
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Canción actual
                  if (room.hasCurrentTrack) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const EqualizerBars(height: 11, barWidth: 2.2),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            room.currentVideoTitle!,
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
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Room Card (lista vertical) ────────────────────────────────────────────────

class RoomListCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  final void Function(Room)? onEdit;
  final void Function(Room)? onClose;

  const RoomListCard({
    super.key,
    required this.room,
    required this.onTap,
    this.onEdit,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isPrivate = room.isPrivate;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radiusLg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radiusLg),
            border: Border.all(color: appDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(spacingMd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    _RoomThumbnail(room: room),
                    const SizedBox(width: spacingMd),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  room.name,
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPrivate) ...[
                                const SizedBox(width: spacingXs),
                                _PrivatePill(),
                              ],
                            ],
                          ),

                          if (room.hasCurrentTrack) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const EqualizerBars(height: 12, barWidth: 2.5),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    room.currentVideoTitle!,
                                    style: const TextStyle(
                                      color: appEnergy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (room.description != null &&
                              room.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              room.description!,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.6),
                                fontSize: 12,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: spacingSm),

                          Row(
                            children: [
                              Icon(Icons.headphones_outlined,
                                  color: cs.onSurface.withValues(alpha: 0.38),
                                  size: 12),
                              const SizedBox(width: 3),
                              Text(
                                room.listenerCount == 0
                                    ? 'rooms.no_listeners'.tr()
                                    : '${room.listenerCount} oyente${room.listenerCount == 1 ? '' : 's'}',
                                style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.38),
                                    fontSize: 11),
                              ),
                              if (room.listenerCount > 0) ...[
                                const SizedBox(width: spacingXs),
                                const LiveDot(size: 5),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (onEdit != null || onClose != null)
                      _HostMenuButton(
                          room: room, onEdit: onEdit, onClose: onClose)
                    else
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurface.withValues(alpha: 0.38), size: 18),
                  ],
                ),
              ),

              Divider(height: 1, color: appDivider),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: spacingMd, vertical: 9),
                child: Row(
                  children: [
                    _HostPill(username: room.hostUsername),
                    if (room.genres.isNotEmpty) ...[
                      const SizedBox(width: spacingXs),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            children: room.genres
                                .take(3)
                                .map((g) => Padding(
                                      padding:
                                          const EdgeInsets.only(right: 4),
                                      child: _GenrePill(genre: g),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (room.maxParticipants != null) ...[
                      const SizedBox(width: spacingXs),
                      Icon(Icons.people_outline,
                          color: cs.onSurface.withValues(alpha: 0.38), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${room.maxParticipants}',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.38),
                            fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Thumbnail de sala ─────────────────────────────────────────────────────────

class _RoomThumbnail extends StatelessWidget {
  final Room room;
  const _RoomThumbnail({required this.room});

  Color _accentColor() {
    const colors = kRoomGenreColors;
    if (room.genres.isEmpty) return colors[room.name.hashCode.abs() % colors.length];
    return colors[room.genres.first.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = hexToColorOrNull(room.accentColor) ?? _accentColor();
    final cover = room.coverImageUrl;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: appDivider),
      ),
      clipBehavior: Clip.hardEdge,
      child: room.currentVideoThumbnail != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  url: room.currentVideoThumbnail!,
                  fit: BoxFit.cover,
                  errorBuilder: (_) =>
                      _ThumbnailPlaceholder(accent: accent, room: room),
                ),
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.music_note_rounded,
                          color: appEnergy, size: 10),
                    ),
                  ),
                ),
              ],
            )
          : (cover != null && cover.isNotEmpty)
              ? AppImage(
                  url: cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_) =>
                      _ThumbnailPlaceholder(accent: accent, room: room),
                )
              : _ThumbnailPlaceholder(accent: accent, room: room),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final Color accent;
  final Room room;
  const _ThumbnailPlaceholder({required this.accent, required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        room.name.isNotEmpty ? room.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: accent,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Fondo de color para cards sin thumbnail ───────────────────────────────────

class _ColorBackground extends StatelessWidget {
  final Color accent;
  const _ColorBackground({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.35),
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
    );
  }
}

// ── Pills ─────────────────────────────────────────────────────────────────────

class _PrivatePill extends StatelessWidget {
  const _PrivatePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: appAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(color: appAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, color: appAccent, size: 10),
          SizedBox(width: 3),
          Text(
            'room.private_room'.tr(),
            style: TextStyle(
              color: appAccent,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostPill extends StatelessWidget {
  final String username;
  const _HostPill({required this.username});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(color: appDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
                color: context.appCard2Color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(
                  color: context.appTextSecColor, fontSize: 9, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 5),
          Text(username,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _GenrePill extends StatelessWidget {
  final String genre;
  const _GenrePill({required this.genre});

  @override
  Widget build(BuildContext context) {
    final c = kRoomGenreColors[genre.hashCode.abs() % kRoomGenreColors.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radiusFull),
      ),
      child: Text(genre,
          style: TextStyle(
              color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Menú de host (···) ────────────────────────────────────────────────────────

class _HostMenuButton extends StatelessWidget {
  final Room room;
  final void Function(Room)? onEdit;
  final void Function(Room)? onClose;
  final bool dark;

  const _HostMenuButton({
    required this.room,
    this.onEdit,
    this.onClose,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: dark ? Colors.white70 : cs.onSurface.withValues(alpha: 0.38),
        size: 18,
      ),
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        side: BorderSide(color: appDivider),
      ),
      onSelected: (value) {
        if (value == 'edit') onEdit?.call(room);
        if (value == 'close') onClose?.call(room);
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 16,
                    color: cs.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: spacingSm),
                Text('room.edit_room'.tr(),
                    style: TextStyle(color: cs.onSurface, fontSize: 13)),
              ],
            ),
          ),
        if (onClose != null)
          PopupMenuItem(
            value: 'close',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: appError),
                SizedBox(width: spacingSm),
                Text('rooms.close_button'.tr(),
                    style: TextStyle(color: appError, fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}
