import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Imagen de red con caché en memoria y disco (`cached_network_image`).
///
/// Reemplaza a `Image.network`: evita re-descargar la misma miniatura/avatar en
/// cada scroll o rebuild, muestra un placeholder neutro mientras carga y aparece
/// con un fundido suave. Si la URL está vacía o la carga falla, usa
/// [errorBuilder] (o un relleno neutro por defecto).
class AppImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Widget a mostrar si la imagen falla o la URL está vacía.
  final Widget Function(BuildContext context)? errorBuilder;

  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext c) =>
        errorBuilder?.call(c) ??
        Container(width: width, height: height, color: c.appSurfaceAltColor);

    if (url.isEmpty) return fallback(context);

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (c, _) => Container(
        width: width,
        height: height,
        color: c.appCard2Color,
      ),
      errorWidget: (c, _, _) => fallback(c),
    );
  }
}
