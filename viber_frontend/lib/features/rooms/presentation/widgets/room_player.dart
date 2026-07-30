import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/motion.dart';
import '../../../social/infrastructure/liked_songs_service.dart';
import '../yt_bridge.dart';

/// Widget del reproductor de sala. Muestra el iframe de YouTube ([YoutubePlayerIsolated]),
/// el título del vídeo actual, la barra de progreso con tiempos y los controles
/// de play/pause/anterior/siguiente (solo visibles si [isHost] es true).
/// Incluye botón ♥ para guardar la canción actual como favorita.
class RoomPlayer extends StatefulWidget {
  final YtBridge ytBridge;
  final String? currentVideoId;
  final String? currentVideoTitle;
  final String? currentVideoThumbnail;
  final bool playing;
  final bool isHost;
  final double currentSeconds;
  final double totalSeconds;
  final bool isDragging;
  final double dragValue;
  final ScrollController? scrollController;

  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  final bool hasNext;
  final bool hasPrev;

  const RoomPlayer({
    super.key,
    required this.ytBridge,
    required this.currentVideoId,
    required this.currentVideoTitle,
    this.currentVideoThumbnail,
    required this.playing,
    required this.isHost,
    required this.currentSeconds,
    required this.totalSeconds,
    required this.isDragging,
    required this.dragValue,
    this.scrollController,
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrev,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
    this.hasNext = false,
    this.hasPrev = false,
  });

  @override
  State<RoomPlayer> createState() => _RoomPlayerState();
}

class _RoomPlayerState extends State<RoomPlayer> {
  final _likedSongsService = LikedSongsService();
  String? _likedVideoId;
  bool?   _isLiked;
  bool    _toggling = false;

  @override
  void initState() {
    super.initState();
    _checkLiked(widget.currentVideoId);
  }

  @override
  void didUpdateWidget(RoomPlayer old) {
    super.didUpdateWidget(old);
    if (old.currentVideoId != widget.currentVideoId) {
      _checkLiked(widget.currentVideoId);
    }
  }

  Future<void> _checkLiked(String? videoId) async {
    if (videoId == null) {
      if (mounted) setState(() { _isLiked = null; _likedVideoId = null; });
      return;
    }
    if (mounted) setState(() { _isLiked = null; _likedVideoId = videoId; });
    try {
      final liked = await _likedSongsService.isLiked(videoId);
      if (mounted && _likedVideoId == videoId) setState(() => _isLiked = liked);
    } catch (_) {
      if (mounted && _likedVideoId == videoId) setState(() => _isLiked = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_toggling || widget.currentVideoId == null) return;
    Haptics.light();
    setState(() => _toggling = true);
    try {
      if (_isLiked == true) {
        await _likedSongsService.unlikeSong(widget.currentVideoId!);
        if (mounted) setState(() => _isLiked = false);
      } else {
        await _likedSongsService.likeSong(
          videoId: widget.currentVideoId!,
          title: widget.currentVideoTitle ?? widget.currentVideoId!,
          thumbnailUrl: widget.currentVideoThumbnail,
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

  String _fmt(double s) {
    final d = Duration(seconds: s.toInt());
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // El contenedor "respira" cuando hay reproducción: borde coral + halo suave,
    // que se apaga al pausar. Es el momento estrella de la sala.
    final playing = widget.playing && widget.currentVideoId != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: playing ? appEnergy.withValues(alpha: 0.45) : appDivider,
        ),
        boxShadow: playing
            ? [
                BoxShadow(
                  color: appEnergy.withValues(alpha: 0.16),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Video ──────────────────────────────────────────────────────────
          widget.currentVideoId != null
              ? widget.ytBridge.buildPlayerWidget(
                  scrollController: widget.scrollController)
              : _buildEmptyPlaceholder(context),

          const SizedBox(height: 14),

          // ── Título + botón ♥ ───────────────────────────────────────────────
          if (widget.currentVideoTitle != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.playing) ...[
                    const EqualizerBars(height: 16, barWidth: 3, barCount: 4),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      widget.currentVideoTitle!,
                      style: TextStyle(
                          color: context.appTextPrimColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLikeButton(context),
                ],
              ),
            ),

          // ── Barra de progreso ──────────────────────────────────────────────
          if (widget.currentVideoId != null) ...[
            const SizedBox(height: 4),
            _buildProgressBar(context),
          ],

          // ── Controles host ─────────────────────────────────────────────────
          if (widget.isHost) ...[
            const SizedBox(height: 12),
            _buildControls(context),
          ],
        ],
      ),
    );
  }

  Widget _buildLikeButton(BuildContext context) {
    if (widget.currentVideoId == null) return const SizedBox.shrink();

    if (_toggling) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(7),
          child: CircularProgressIndicator(strokeWidth: 1.5, color: appAccent),
        ),
      );
    }

    final liked = _isLiked ?? false;
    return Tooltip(
      message: liked ? 'Quitar de favoritos' : 'Añadir a favoritos',
      child: InkWell(
        onTap: _toggleLike,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(liked),
            size: 22,
            color: liked ? appAccent : context.appTextSecColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: context.appSurfaceAltColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_outlined, color: context.appTextSecColor, size: 32),
            const SizedBox(height: 8),
            Text('Sin canción en reproducción',
                style: TextStyle(color: context.appTextSecColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final cur = widget.isDragging ? widget.dragValue : widget.currentSeconds;
    final tot = widget.totalSeconds > 0 ? widget.totalSeconds : 1.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: appEnergy,
            inactiveTrackColor: appEnergy.withValues(alpha: 0.22),
            thumbColor: appEnergy,
            thumbShape: widget.isHost
                ? const RoundSliderThumbShape(enabledThumbRadius: 7)
                : SliderComponentShape.noThumb,
            overlayColor: appEnergyGlow,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            trackHeight: 3,
          ),
          child: Slider(
            value: cur.clamp(0.0, tot),
            min: 0.0,
            max: tot,
            onChangeStart: widget.isHost ? widget.onSeekStart : null,
            onChanged: widget.isHost ? (v) => widget.onSeekChanged(v) : null,
            onChangeEnd: widget.isHost ? widget.onSeekEnd : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(cur),
                  style: TextStyle(color: context.appTextSecColor, fontSize: 11)),
              Text(_fmt(tot),
                  style: TextStyle(color: context.appTextSecColor, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── Botón PREV ──────────────────────────────────────────────
        GestureDetector(
          onTap: widget.hasPrev ? widget.onPrev : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.hasPrev
                  ? context.appSurfaceAltColor
                  : context.appSurfaceAltColor.withOpacity(0.4),
              border: Border.all(
                color: widget.hasPrev
                    ? appDivider
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              Icons.skip_previous_rounded,
              color: widget.hasPrev
                  ? context.appTextPrimColor
                  : context.appTextSecColor.withOpacity(0.3),
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // ── Botón PLAY / PAUSE ──────────────────────────────────────
        PressableScale(
          onTap: widget.playing ? widget.onPause : widget.onPlay,
          pressedScale: 0.9,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appAccent,
              boxShadow: [
                BoxShadow(
                  color: appAccent.withValues(alpha: widget.playing ? 0.55 : 0.3),
                  blurRadius: widget.playing ? 22 : 12,
                  spreadRadius: widget.playing ? 3 : 1,
                )
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                widget.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                key: ValueKey(widget.playing),
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // ── Botón NEXT ───────────────────────────────────────────────
        GestureDetector(
          onTap: widget.hasNext ? widget.onNext : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.hasNext
                  ? context.appSurfaceAltColor
                  : context.appSurfaceAltColor.withOpacity(0.4),
              border: Border.all(
                color: widget.hasNext
                    ? appDivider
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              Icons.skip_next_rounded,
              color: widget.hasNext
                  ? context.appTextPrimColor
                  : context.appTextSecColor.withOpacity(0.3),
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}
