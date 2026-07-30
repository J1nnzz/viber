import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Helper estático para mostrar snackbars flotantes de forma consistente en toda la app.
/// Usa fondo de error ([appError]) cuando [error] es true; fondo de superficie en caso contrario.
class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    if (!Navigator.of(context).mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 13)),
      backgroundColor:
          error ? appError : Theme.of(context).colorScheme.surface,
      behavior:  SnackBarBehavior.floating,
      width:     320,
      duration:  const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd)),
    ));
  }
}
