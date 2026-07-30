import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/auth/infrastructure/auth_service.dart';

/// Clase base para todos los servicios que consumen la API REST del backend.
///
/// Provee el token JWT almacenado y las cabeceras de autenticación listas para usar.
/// El método [throwFromResponse] extrae el mensaje de error del JSON y lanza una [Exception].
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

  Never throwFromResponse(http.Response res, String fallback) {
    final body = jsonDecode(res.body);
    final msg  = body is Map ? (body['error'] ?? fallback) : fallback;
    throw Exception(msg);
  }
}
