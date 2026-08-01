import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';

/// Traduce los errores que devuelve la API al idioma elegido en la app.
///
/// El backend responde `{"error": "...", "code": "..."}`. No traduce él porque
/// no sabe qué idioma tiene puesto el usuario: se elige en Ajustes y puede no
/// coincidir con el del dispositivo ni con `Accept-Language`. Lo que hace es
/// decir *qué* ha fallado mediante un código estable, y aquí se convierte en
/// texto.
///
/// Si el código es desconocido —cliente viejo contra servidor nuevo, o un
/// error todavía sin migrar— se usa el campo `error` tal cual. Nunca se muestra
/// un código en crudo.
class ApiError {
  ApiError._();

  /// Prefijo de las claves de traducción: `errors.api.<CODE>`.
  static const String _prefix = 'errors.api.';

  /// Mensaje ya traducido a partir del cuerpo de una respuesta de error.
  ///
  /// [body] es el cuerpo sin decodificar. [fallback] se usa si la respuesta no
  /// es JSON válido o no trae ni `code` ni `error` (por ejemplo, un 502 del
  /// proxy con HTML).
  static String fromBody(String body, {required String fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return fromMap(decoded, fallback: fallback);
      }
    } catch (_) {
      // cuerpo no JSON: nos quedamos con el fallback
    }
    return fallback;
  }

  /// Igual que [fromBody] pero partiendo del mapa ya decodificado.
  static String fromMap(Map<String, dynamic> data, {required String fallback}) {
    final code = data['code'];
    if (code is String && code.isNotEmpty) {
      final key = '$_prefix$code';
      final translated = key.tr();
      // easy_localization devuelve la propia clave cuando no la encuentra:
      // eso significa que este cliente no conoce el código todavía.
      if (translated != key) return translated;
    }

    final message = data['error'];
    if (message is String && message.trim().isNotEmpty) return message;

    return fallback;
  }
}
