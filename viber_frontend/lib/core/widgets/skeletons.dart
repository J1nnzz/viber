import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Esqueletos de carga reutilizables (siluetas con shimmer)
// ══════════════════════════════════════════════════════════════════════════════
// Sustituyen al spinner suelto: el contenido "aparece" en su sitio, sin salto de
// layout y con sensación de mayor rapidez. Construidos sobre [ShimmerBox].
// ══════════════════════════════════════════════════════════════════════════════

/// Fila-esqueleto genérica: miniatura/avatar + dos líneas. Sirve para listas de
/// usuarios, conversaciones, canciones favoritas, etc.
class SkeletonTile extends StatelessWidget {
  /// true → avatar circular; false → miniatura cuadrada.
  final bool circleLeading;

  const SkeletonTile({super.key, this.circleLeading = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: 11),
      child: Row(
        children: [
          ShimmerBox(
            width: 44,
            height: 44,
            borderRadius:
                BorderRadius.circular(circleLeading ? 22 : radiusMd),
          ),
          const SizedBox(width: spacingMd),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerBox(width: 150, height: 13),
              SizedBox(height: 8),
              ShimmerBox(width: 90, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lista de filas-esqueleto.
class SkeletonList extends StatelessWidget {
  final int count;
  final bool circleLeading;

  const SkeletonList({super.key, this.count = 7, this.circleLeading = true});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: spacingXs),
      itemCount: count,
      itemBuilder: (context, _) => SkeletonTile(circleLeading: circleLeading),
    );
  }
}

/// Esqueleto de conversación: burbujas alternas a izquierda y derecha.
class SkeletonChat extends StatelessWidget {
  const SkeletonChat({super.key});

  static const _widths = [0.50, 0.66, 0.40, 0.72, 0.55, 0.46, 0.62];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(spacingMd),
      itemCount: _widths.length,
      itemBuilder: (context, i) {
        final mine = i.isOdd;
        final w = MediaQuery.of(context).size.width * _widths[i];
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShimmerBox(
              width: w,
              height: 38,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
