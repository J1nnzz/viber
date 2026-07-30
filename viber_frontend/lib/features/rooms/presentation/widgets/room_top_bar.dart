import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// AppBar personalizada de la sala que muestra el nombre, género principal,
/// número de oyentes y el indicador de conexión WebSocket.
class RoomTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final String? genre;
  final int listenerCount;
  final bool connected;

  const RoomTopBar({
    super.key,
    required this.name,
    this.genre,
    required this.listenerCount,
    required this.connected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        border: Border(bottom: BorderSide(color: appDivider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: context.appTextSecColor, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: context.appTextPrimColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2)),
                if (genre != null)
                  Text(genre!,
                      style: TextStyle(
                          color: context.appTextSecColor, fontSize: 11)),
              ],
            ),
          ),
          // Contador oyentes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: appEnergyGlow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: appEnergy.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: appEnergy, size: 14),
                const SizedBox(width: 5),
                Text('$listenerCount',
                    style: const TextStyle(
                        color: appEnergy,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Indicador conexión
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? const Color(0xFF4ADE80) : Colors.red,
              boxShadow: connected
                  ? [BoxShadow(
                      color: const Color(0xFF4ADE80).withOpacity(0.5),
                      blurRadius: 6)]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}