import 'package:http/http.dart' as http;
import '../errors/api_error.dart';
import '../../features/auth/infrastructure/auth_service.dart';

/// Clase base para todos los servicios que consumen la API REST del backend.
///
/// Provee el token JWT almacenado y las cabeceras de autenticación listas para usar.
/// El método [throwFromResponse] traduce el error del backend y lanza una [Exception].
abstract class BaseApiService {
  final _auth = AuthService();

  Future<String?> getToken() => _auth.getToken();

  Future<Map<String, String>> authHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Lanza una excepción con el error de la respuesta ya traducido.
  ///
  /// Pasa por [ApiError], que prefiere el `code` estable del backend sobre el
  /// texto: así el mensaje sale en el idioma elegido en la app y no en el del
  /// servidor. Si el código es desconocido cae al texto que venga, y si no hay
  /// nada aprovechable, a [fallback].
  Never throwFromResponse(http.Response res, String fallback) {
    throw Exception(ApiError.fromBody(res.body, fallback: fallback));
  }
}
