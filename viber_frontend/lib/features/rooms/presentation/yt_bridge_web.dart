import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

enum YtState { unstarted, playing, paused, buffering, ended, cued }

class YtBridge {
  late final YoutubePlayerController _ctrl;

  YtBridge() {
    _ctrl = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
        showVideoAnnotations: false,
        playsInline: true,
      ),
    );
  }

  Future<void> loadVideo(String videoId,
      {double startAt = 0, bool autoPlay = true}) {
    if (autoPlay) {
      return _ctrl.loadVideoById(videoId: videoId, startSeconds: startAt);
    } else {
      return _ctrl.cueVideoById(videoId: videoId, startSeconds: startAt);
    }
  }

  Future<void> play() => _ctrl.playVideo();
  Future<void> pause() => _ctrl.pauseVideo();

  Future<void> seekTo(double seconds, {bool allowSeekAhead = true}) =>
      _ctrl.seekTo(seconds: seconds, allowSeekAhead: allowSeekAhead);

  Future<double> get currentTime => _ctrl.currentTime;
  Future<double> get duration => _ctrl.duration;

  void setStateCallback(void Function(YtState) callback) {
    _ctrl.listen((event) {
      switch (event.playerState) {
        case PlayerState.playing:
          callback(YtState.playing);
        case PlayerState.paused:
          callback(YtState.paused);
        case PlayerState.ended:
          callback(YtState.ended);
        case PlayerState.buffering:
          callback(YtState.buffering);
        case PlayerState.cued:
          callback(YtState.cued);
        default:
          callback(YtState.unstarted);
      }
    });
  }

  Widget buildPlayerWidget({ScrollController? scrollController}) {
    return _WebPlayer(ctrl: _ctrl, scrollController: scrollController);
  }

  void dispose() => _ctrl.close();
}

class _WebPlayer extends StatelessWidget {
  final YoutubePlayerController ctrl;
  final ScrollController? scrollController;
  const _WebPlayer({required this.ctrl, this.scrollController});

  void _forward(BuildContext context, double dy) {
    if (scrollController != null && scrollController!.hasClients) {
      final pos = scrollController!.position;
      pos.jumpTo(
          (pos.pixels + dy).clamp(pos.minScrollExtent, pos.maxScrollExtent));
      return;
    }
    final s = Scrollable.maybeOf(context);
    if (s != null) {
      s.position.jumpTo((s.position.pixels + dy)
          .clamp(s.position.minScrollExtent, s.position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: ctrl,
      builder: (context, player) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) _forward(context, e.scrollDelta.dy);
                },
                behavior: HitTestBehavior.translucent,
                child: player,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
