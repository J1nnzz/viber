import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

enum YtState { unstarted, playing, paused, buffering, ended, cued }

/// Implementación móvil (Android / iOS) del puente con el reproductor de YouTube.
///
/// Usa [youtube_player_flutter], que renderiza la IFrame API de YouTube en una
/// WebView nativa.
///
/// IMPORTANTE: el controlador se crea de forma **lazy**, es decir, solo cuando
/// se llama a [loadVideo] por primera vez, con el videoId real.  De esta forma
/// nunca se carga ningún vídeo placeholder (el "dQw4w9WgXcQ" que provocaba que
/// se mostrase Rick Astley al entrar a una sala).
class YtBridge {
  YoutubePlayerController? _ctrl;
  void Function(YtState)? _stateCallback;
  PlayerState? _lastState;
  bool _hasRealVideo = false;

  YtBridge();

  // ── Listener interno del controlador ──────────────────────────────────────
  void _onUpdate() {
    if (!_hasRealVideo || _ctrl == null) return;
    final newState = _ctrl!.value.playerState;
    if (newState == _lastState) return;
    _lastState = newState;
    if (_stateCallback == null) return;
    switch (newState) {
      case PlayerState.playing:
        _stateCallback!(YtState.playing);
      case PlayerState.paused:
        _stateCallback!(YtState.paused);
      case PlayerState.ended:
        _stateCallback!(YtState.ended);
      case PlayerState.buffering:
        _stateCallback!(YtState.buffering);
      case PlayerState.cued:
        _stateCallback!(YtState.cued);
      default:
        _stateCallback!(YtState.unstarted);
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  Future<void> loadVideo(String videoId,
      {double startAt = 0, bool autoPlay = true}) async {
    _hasRealVideo = true;
    _lastState = null;

    if (_ctrl == null) {
      // Primera carga: crear el controlador directamente con el video real.
      // No se usa ningún placeholder para evitar mostrar vídeos no deseados.
      _ctrl = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: autoPlay,
          mute: false,
          hideControls: true,
          controlsVisibleAtStart: false,
          enableCaption: false,
          forceHD: false,
          startAt: startAt.toInt(),
        ),
      );
      _ctrl!.addListener(_onUpdate);
    } else {
      // Videos siguientes: reusar el mismo controlador / WebView.
      if (autoPlay) {
        _ctrl!.load(videoId, startAt: startAt.toInt());
      } else {
        _ctrl!.cue(videoId, startAt: startAt.toInt());
      }
    }
  }

  Future<void> play() async {
    if (!_hasRealVideo || _ctrl == null) return;
    _ctrl!.play();
  }

  Future<void> pause() async {
    if (!_hasRealVideo || _ctrl == null) return;
    _ctrl!.pause();
  }

  Future<void> seekTo(double seconds, {bool allowSeekAhead = true}) async {
    if (!_hasRealVideo || _ctrl == null) return;
    _ctrl!.seekTo(Duration(milliseconds: (seconds * 1000).toInt()));
  }

  Future<double> get currentTime async {
    if (_ctrl == null) return 0.0;
    return _ctrl!.value.position.inMilliseconds / 1000.0;
  }

  Future<double> get duration async {
    if (_ctrl == null) return 0.0;
    return _ctrl!.value.metaData.duration.inMilliseconds / 1000.0;
  }

  void setStateCallback(void Function(YtState) callback) {
    _stateCallback = callback;
  }

  Widget buildPlayerWidget({ScrollController? scrollController}) {
    // Si el controlador aún no existe (no se ha cargado ningún video real)
    // devolver un widget vacío; el padre ya muestra el placeholder.
    if (_ctrl == null) return const SizedBox.shrink();
    return _MobilePlayer(ctrl: _ctrl!);
  }

  void dispose() {
    _ctrl?.removeListener(_onUpdate);
    _ctrl?.dispose();
    _ctrl = null;
  }
}

class _MobilePlayer extends StatelessWidget {
  final YoutubePlayerController ctrl;
  const _MobilePlayer({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: ctrl,
              showVideoProgressIndicator: false,
            ),
          ),
        ),
      ),
    );
  }
}
