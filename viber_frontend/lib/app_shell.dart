import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/rooms/presentation/active_room_provider.dart';
import 'features/rooms/presentation/mini_player.dart';
import 'features/rooms/presentation/room_screen.dart';
import 'core/theme/app_theme.dart';

/// Shell raíz de la app.
///
/// El RoomScreen vive AQUÍ como widget del Stack, nunca como ruta del
/// Navigator. Así el YoutubePlayerController permanece montado cuando se
/// minimiza la sala, y el MiniPlayer puede recibir toques sin bloqueos.
///
/// Estructura del Stack (de abajo a arriba):
///   1. child (HomeScreen) — siempre visible
///   2. RoomScreen — full-screen cuando activo; Offstage+IgnorePointer cuando minimizado
///   3. MiniPlayer — overlay flotante; solo visible cuando minimizado
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveRoomProvider>(
      builder: (context, provider, _) {
        // Mostrar aviso de expulsión en el siguiente frame
        if (provider.kickedRoomName != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Fuiste expulsado de "${provider.kickedRoomName}" por el host',
                  style: const TextStyle(fontSize: 13),
                ),
                backgroundColor: appError,
                behavior: SnackBarBehavior.floating,
                width: 360,
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radiusMd)),
              ),
            );
            provider.clearKicked();
          });
        }

        // Mostrar aviso de sala llena (entrada rechazada)
        if (provider.roomFullName != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'La sala "${provider.roomFullName}" está llena',
                  style: const TextStyle(fontSize: 13),
                ),
                backgroundColor: appError,
                behavior: SnackBarBehavior.floating,
                width: 360,
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radiusMd)),
              ),
            );
            provider.clearRoomFull();
          });
        }

        // Mostrar aviso de sala cerrada por el host
        if (provider.roomClosedName != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'El host ha cerrado la sala "${provider.roomClosedName}"',
                  style: const TextStyle(fontSize: 13),
                ),
                backgroundColor: appError,
                behavior: SnackBarBehavior.floating,
                width: 360,
                duration: const Duration(seconds: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radiusMd)),
              ),
            );
            provider.clearRoomClosed();
          });
        }

        return Stack(
          children: [
            // ── 1. Pantalla principal (salas, perfil, etc.) ──────────────────
            widget.child,

            // ── 2. Sala activa ───────────────────────────────────────────────
            // Siempre en el árbol cuando hay sala activa; solo se oculta/
            // congela con Offstage+IgnorePointer al minimizar.
            // ValueKey garantiza que Flutter reutilice el State (y por tanto
            // el YoutubePlayerController) aunque cambien los wrappers.
            if (provider.isActive)
              Offstage(
                offstage: provider.isMinimized,
                child: RoomScreen(
                  key: ValueKey(provider.room!.id),
                  room: provider.room!,
                ),
              ),

            // ── 3. Mini-player flotante ──────────────────────────────────────
            const MiniPlayer(),
          ],
        );
      },
    );
  }
}
