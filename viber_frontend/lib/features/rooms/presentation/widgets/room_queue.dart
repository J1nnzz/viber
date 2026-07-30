import 'package:flutter/material.dart';
import '../../../rooms/domain/room_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../social/infrastructure/liked_songs_service.dart';

/// Widget de la cola de reproducción.
///
/// Cuando [canManageQueue] es true (Host o DJ):
///   - Drag & drop para reordenar (ReorderableListView)
///   - Botón de borrar en cada item (swipe o icono)
///   - Botón "Añadir" en el header
///
/// Los callbacks [onRemove] y [onMove] emiten los mensajes WebSocket
/// correspondientes (QUEUE_REMOVE y QUEUE_MOVE) desde el padre (RoomScreen).
class RoomQueue extends StatelessWidget {
  final List<QueueItem> queue;
  final bool canManageQueue;
  final VoidCallback onAddSong;

  /// Emite QUEUE_REMOVE con el índice a eliminar.
  final void Function(int index) onRemove;

  /// Emite QUEUE_MOVE con índice origen y destino.
  final void Function(int from, int to) onMove;

  const RoomQueue({
    super.key,
    required this.queue,
    required this.canManageQueue,
    required this.onAddSong,
    required this.onRemove,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 4),
          if (queue.isEmpty)
            _buildEmpty(context)
          else
            canManageQueue ? _buildReorderable(context) : _buildReadOnly(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        children: [
          Text(
            'Cola de reproducción',
            style: TextStyle(
              color: context.appTextPrimColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (canManageQueue)
            TextButton.icon(
              onPressed: onAddSong,
              icon: const Icon(Icons.add, size: 15, color: appAccent),
              label: const Text(
                'Añadir',
                style: TextStyle(
                  color: appAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: appAccentGlow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded,
                color: context.appTextSecColor.withOpacity(0.5), size: 30),
            const SizedBox(height: 8),
            Text(
              'La cola está vacía',
              style: TextStyle(
                  color: context.appTextSecColor.withOpacity(0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lista solo lectura (oyentes) ───────────────────────────────────────────

  Widget _buildReadOnly(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: queue.length,
      separatorBuilder: (_, __) =>
          Divider(color: appDivider, height: 1),
      itemBuilder: (ctx, i) => _QueueTile(
        item: queue[i],
        index: i,
        canManageQueue: false,
        onRemove: null,
      ),
    );
  }

  // ── Lista reordenable (Host / DJ) ──────────────────────────────────────────

  Widget _buildReorderable(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: queue.length,
      onReorder: (oldIndex, newIndex) {
        int to = newIndex;
        if (newIndex > oldIndex) to = newIndex - 1;
        if (oldIndex != to) onMove(oldIndex, to);
      },
      itemBuilder: (ctx, i) => _QueueTile(
        key: ValueKey('queue_${i}_${queue[i].videoId}'),
        item: queue[i],
        index: i,
        canManageQueue: true,
        onRemove: () => onRemove(i),
      ),
      proxyDecorator: (child, index, animation) => Material(
        color: context.appSurfaceAltColor,
        borderRadius: BorderRadius.circular(8),
        elevation: 4,
        child: child,
      ),
    );
  }
}

// ── Tile individual ────────────────────────────────────────────────────────────

class _QueueTile extends StatefulWidget {
  final QueueItem item;
  final int index;
  final bool canManageQueue;
  final VoidCallback? onRemove;

  const _QueueTile({
    super.key,
    required this.item,
    required this.index,
    required this.canManageQueue,
    required this.onRemove,
  });

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
  final _likedSongsService = LikedSongsService();
  bool? _isLiked;       // null = cargando, true/false = estado conocido
  bool  _toggling = false;

  @override
  void initState() {
    super.initState();
    _checkLiked();
  }

  @override
  void didUpdateWidget(_QueueTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.videoId != widget.item.videoId) {
      setState(() => _isLiked = null);
      _checkLiked();
    }
  }

  Future<void> _checkLiked() async {
    try {
      final liked = await _likedSongsService.isLiked(widget.item.videoId);
      if (mounted) setState(() => _isLiked = liked);
    } catch (_) {
      if (mounted) setState(() => _isLiked = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_toggling) return;
    Haptics.light();
    setState(() => _toggling = true);
    try {
      if (_isLiked == true) {
        await _likedSongsService.unlikeSong(widget.item.videoId);
        if (mounted) setState(() => _isLiked = false);
      } else {
        await _likedSongsService.likeSong(
          videoId: widget.item.videoId,
          title: widget.item.title,
          thumbnailUrl: widget.item.thumbnail.isNotEmpty ? widget.item.thumbnail : null,
        );
        if (mounted) setState(() => _isLiked = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liked = _isLiked ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle de arrastre — solo visible para Host/DJ
          if (widget.canManageQueue)
            ReorderableDragStartListener(
              index: widget.index,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.drag_handle_rounded,
                    color: context.appTextSecColor, size: 18),
              ),
            )
          else
            SizedBox(
              width: 20,
              child: Text(
                '${widget.index + 1}',
                style: TextStyle(color: context.appTextSecColor, fontSize: 12),
              ),
            ),
          if (widget.canManageQueue)
            SizedBox(
              width: 20,
              child: Text(
                '${widget.index + 1}',
                style: TextStyle(color: context.appTextSecColor, fontSize: 12),
              ),
            ),
          const SizedBox(width: 6),
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: widget.item.thumbnail.isNotEmpty
                ? AppImage(url: widget.item.thumbnail,
                    width: 48, height: 36, fit: BoxFit.cover)
                : Container(
                    width: 48,
                    height: 36,
                    color: context.appSurfaceAltColor,
                    child: Icon(Icons.music_note,
                        color: context.appTextSecColor, size: 18)),
          ),
        ],
      ),
      title: Text(
        widget.item.title,
        style: TextStyle(
          color: context.appTextPrimColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        widget.item.addedBy,
        style: TextStyle(color: context.appTextSecColor, fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de favorito — disponible para todos
          _toggling
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: appAccent),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: liked ? appAccent : context.appTextSecColor,
                  ),
                  splashRadius: 18,
                  tooltip: liked ? 'Quitar de favoritos' : 'Añadir a favoritos',
                  onPressed: _toggleLike,
                ),
          // Botón de borrar — solo Host/DJ
          if (widget.canManageQueue)
            IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 18, color: context.appTextSecColor),
              splashRadius: 18,
              tooltip: 'Eliminar de la cola',
              onPressed: widget.onRemove,
            ),
        ],
      ),
    );
  }
}
