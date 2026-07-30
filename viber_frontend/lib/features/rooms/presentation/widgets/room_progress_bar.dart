import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

// Widget aislado para la barra de progreso de la sala.
//
// Tiene su propio State con GlobalKey<RoomProgressBarState>, lo que permite
// que el timer y los handlers de room_screen llamen a
//   progressKey.currentState?.update()
// directamente, sin necesidad de StateSetter closures que se vuelven obsoletos
// en cada rebuild del árbol padre (Bug 1 corregido).

class RoomProgressBar extends StatefulWidget {
  final bool isHost;
  final double Function() getCurrentSeconds;
  final double Function() getTotalSeconds;
  final bool Function() getIsDragging;
  final double Function() getDragValue;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;

  const RoomProgressBar({
    super.key,
    required this.isHost,
    required this.getCurrentSeconds,
    required this.getTotalSeconds,
    required this.getIsDragging,
    required this.getDragValue,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  @override
  State<RoomProgressBar> createState() => RoomProgressBarState();
}

class RoomProgressBarState extends State<RoomProgressBar> {
  /// Fuerza un repaint. Llamado desde room_screen via la GlobalKey.
  void update() {
    if (mounted) setState(() {});
  }

  String _fmt(double s) {
    final d = Duration(seconds: s.toInt());
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDragging = widget.getIsDragging();
    final cur = isDragging ? widget.getDragValue() : widget.getCurrentSeconds();
    final tot = widget.getTotalSeconds() > 0 ? widget.getTotalSeconds() : 1.0;

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
            onChanged: widget.isHost ? widget.onSeekChanged : null,
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
}