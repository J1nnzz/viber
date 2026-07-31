import 'package:easy_localization/easy_localization.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:viber/core/theme/app_theme.dart';

/// Reproductor del modo audio (estilo Heardle).
///
/// Reproduce siempre desde el segundo 0 y se corta automáticamente al llegar
/// a [unlockedSeconds]. La barra muestra los 30 s del preview con marcas en
/// cada paso de desbloqueo y la zona ya desbloqueada resaltada.
class SnippetPlayer extends StatefulWidget {
  final String audioUrl;
  final int unlockedSeconds;
  final List<int> steps; // [1, 2, 4, 7, 12, 30]
  final bool finished;

  const SnippetPlayer({
    super.key,
    required this.audioUrl,
    required this.unlockedSeconds,
    required this.steps,
    required this.finished,
  });

  @override
  State<SnippetPlayer> createState() => _SnippetPlayerState();
}

class _SnippetPlayerState extends State<SnippetPlayer> {
  static const int _totalSeconds = 30;

  final _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;

  bool _loading = true;
  bool _error = false;
  Duration _position = Duration.zero;

  int get _limitSeconds =>
      widget.finished ? _totalSeconds : widget.unlockedSeconds;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(widget.audioUrl);
      _positionSub = _player.positionStream.listen(_onPosition);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  void _onPosition(Duration position) {
    if (!mounted) return;
    setState(() => _position = position);
    // Corte automático al límite desbloqueado
    if (_player.playing &&
        position.inMilliseconds >= _limitSeconds * 1000) {
      _player.pause();
      _player.seek(Duration.zero);
      setState(() => _position = Duration.zero);
    }
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        padding: const EdgeInsets.all(spacingMd),
        decoration: BoxDecoration(
          color: appError.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: appError, size: 18),
            const SizedBox(width: spacingSm),
            Expanded(
              child: Text(
                'quiz.audio_error'.tr(),
                style: TextStyle(color: context.appTextSecColor, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final progress =
        (_position.inMilliseconds / (_totalSeconds * 1000)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(spacingMd),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: context.appDividerColor),
      ),
      child: Row(
        children: [
          // ── Botón play/pause ─────────────────────────────────────────────
          GestureDetector(
            onTap: _loading ? null : _togglePlay,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: appAccent,
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _player.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: spacingMd),
          // ── Barra de progreso segmentada ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return SizedBox(
                      height: 18,
                      child: Stack(
                        children: [
                          // Fondo: 30 s totales
                          _bar(width, context.appCard2Color),
                          // Zona desbloqueada
                          _bar(width * _limitSeconds / _totalSeconds,
                              appEnergy.withValues(alpha: 0.25)),
                          // Progreso de reproducción
                          _bar(width * progress, appEnergy),
                          // Marcas de cada paso de desbloqueo
                          for (final step in widget.steps)
                            if (step < _totalSeconds)
                              Positioned(
                                left: width * step / _totalSeconds,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 2,
                                  color: context.appSurfaceColor,
                                ),
                              ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0:${_position.inSeconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                          color: context.appTextSecColor, fontSize: 11),
                    ),
                    Text(
                      '${_limitSeconds}s / ${_totalSeconds}s',
                      style: const TextStyle(
                        color: appEnergy,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double width, Color color) => Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}
