import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/motion.dart';
import '../presentation/active_room_provider.dart';

/// Mini-player flotante que aparece en la parte inferior de la app
/// cuando el usuario minimiza una sala activa.
///
/// Se muestra sobre el contenido normal vía Stack en AppShell.
/// Toca el widget → vuelve a la sala en pantalla completa.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveRoomProvider>(
      builder: (context, provider, _) {
        // Solo visible cuando hay sala activa Y está minimizada.
        final visible = provider.isActive && provider.isMinimized;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        // 80 = altura del NavigationBar de Material 3; mantiene el player encima.
        const navBarHeight = 80.0;

        // AnimatedSwitcher: el player entra deslizándose desde abajo + fundido,
        // en lugar de aparecer/desaparecer de golpe. Al salir hace lo inverso.
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding + navBarHeight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.6),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: visible
                ? _MiniPlayerContent(
                    key: const ValueKey('mini'), provider: provider)
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        );
      },
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final ActiveRoomProvider provider;
  const _MiniPlayerContent({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final title     = provider.currentVideoTitle ?? 'mini_player.no_playback'.tr();
    final thumbnail = provider.currentVideoThumbnail ?? '';
    final roomName  = provider.room?.name ?? '';

    return GestureDetector(
        onTap: provider.expand,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          height: 64,
          decoration: BoxDecoration(
            color: context.appSurfaceColor,
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: appDivider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radiusMd),
            child: Stack(
              children: [
                Row(
              children: [
                // ── Thumbnail ──────────────────────────────────────────────
                _buildThumbnail(context, thumbnail),

                // ── Info ───────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (provider.playing) ...[
                              const EqualizerBars(
                                  height: 11, barWidth: 2, barCount: 4),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // Indicador de conexión: late cuando está conectado.
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: provider.connected
                                  ? const LiveDot(size: 6, color: appSuccess)
                                  : Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red,
                                      ),
                                    ),
                            ),
                            Expanded(
                              child: Text(
                                roomName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Barra de progreso fina ────────────────────────────────
                // Integrada en el borde inferior del mini-player
                // (se gestiona en el Stack del Container principal)

                // ── Controles ─────────────────────────────────────────────
                _buildControls(context),

                // ── Cerrar (salir de sala) ─────────────────────────────────
                _buildCloseButton(context),
              ],
            ),
                MiniPlayerProgressBar(
                  current: provider.currentSeconds,
                  total: provider.totalSeconds,
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildThumbnail(BuildContext context, String url) {
    return SizedBox(
      width: 64,
      height: 64,
      child: url.isNotEmpty
          ? AppImage(
              url: url,
              fit: BoxFit.cover,
              errorBuilder: (c) => _thumbFallback(c),
            )
          : _thumbFallback(context),
    );
  }

  Widget _thumbFallback(BuildContext context) => Container(
        color: context.appSurfaceAltColor,
        child: Icon(Icons.music_note_rounded,
            color: context.appTextSecColor, size: 24),
      );

  Widget _buildControls(BuildContext context) {
    // Play/Pause solo disponible para el host de la sala
    if (!provider.isCurrentUserHost) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            provider.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: Theme.of(context).colorScheme.onSurface,
            size: 28,
          ),
          onPressed: provider.onTogglePlayPause,
          tooltip: provider.playing ? 'mini_player.pause'.tr() : 'mini_player.play'.tr(),
        ),
      ],
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
      tooltip: 'mini_player.leave_tooltip'.tr(),
      onPressed: () => _confirmLeave(context),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'mini_player.leave_title'.tr(),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'mini_player.leave_confirmation'.tr(),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'common.leave'.tr(),
              style: const TextStyle(color: appError),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      provider.leaveRoom();
    }
  }
}

/// Barra de progreso delgada que se superpone en la parte inferior del mini-player.
/// Usarla dentro de un Stack si se quiere el efecto visual completo.
class MiniPlayerProgressBar extends StatelessWidget {
  final double current;
  final double total;

  const MiniPlayerProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.transparent,
        valueColor: const AlwaysStoppedAnimation<Color>(appEnergy),
        minHeight: 2,
      ),
    );
  }
}