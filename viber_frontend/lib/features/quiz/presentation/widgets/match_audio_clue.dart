import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:viber/core/theme/app_theme.dart';

/// Pista de audio de una ronda del duelo: reproduce el preview servido por proxy
/// ([audioUrl]) con un botón de play/pausa. Se reinstancia cada ronda (key por
/// número de ronda) para cargar el audio nuevo.
class MatchAudioClue extends StatefulWidget {
  final String audioUrl;
  const MatchAudioClue({super.key, required this.audioUrl});

  @override
  State<MatchAudioClue> createState() => _MatchAudioClueState();
}

class _MatchAudioClueState extends State<MatchAudioClue> {
  final _player = AudioPlayer();
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.audioUrl);
      if (mounted) setState(() => _loading = false);
      await _player.play();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.seek(Duration.zero);
      await _player.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Icon(Icons.music_off_rounded, color: appError, size: 80);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _loading ? null : _toggle,
          child: Container(
            width: 96, height: 96,
            decoration: const BoxDecoration(color: appAccent, shape: BoxShape.circle),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(34),
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : Icon(_player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 52),
          ),
        ),
        const SizedBox(height: spacingMd),
        Text('quiz.which_song'.tr(),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 13)),
      ],
    );
  }
}
