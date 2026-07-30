import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:viber/core/constants/api_constants.dart';
import '../domain/auth_repository.dart';

/// Servicio de autenticación: registro, login clásico y login con Google.
///
/// Implementa el patrón singleton porque múltiples servicios lo instancian y
/// GoogleSignIn no puede inicializarse más de una vez en la misma sesión web.
/// El token JWT y el rol se almacenan con FlutterSecureStorage (keychain en iOS,
/// Keystore en Android, localStorage cifrado en web).
class AuthService implements AuthRepository {
  // ── Singleton ──────────────────────────────────────────────────────────────
  // Múltiples servicios (FriendshipService, ChatService…) crean AuthService().
  // En web, cada instancia nueva de GoogleSignIn llama a
  // google.accounts.id.initialize() otra vez → "Future already completed".
  // Con el patrón singleton se garantiza una sola instancia (y una sola
  // inicialización de GoogleSignIn) durante toda la vida de la app.
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _storage = const FlutterSecureStorage();

  // serverClientId solo en móvil; en web lanza un assert si se incluye
  final _googleSignIn = kIsWeb
      ? GoogleSignIn(scopes: ['email', 'profile'])
      : GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId:
              '1000375197009-qkdrlcn486egpq8tqt1sl88r3l25nge2.apps.googleusercontent.com',
        );

  // ── Token JWT y rol ────────────────────────────────────────────────────

  @override
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  @override
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> _saveRole(String role) async {
    await _storage.write(key: 'user_role', value: role);
  }

  @override
  Future<bool> isAdmin() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.authUrl}/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final role = jsonDecode(res.body)['role'] as String? ?? 'USER';
        await _saveRole(role); // actualiza storage si el rol cambió
        return role == 'ADMIN';
      }
    } catch (_) {
      // Sin conectividad o token expirado → fallback al storage
    }

    final stored = await _storage.read(key: 'user_role');
    return stored == 'ADMIN';
  }

  @override
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
    if (!kIsWeb && await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // ── Registro clásico ───────────────────────────────────────────────────

  @override
  Future<void> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.authUrl}/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await saveToken(data['token']);
      await _saveRole(data['role'] ?? 'USER');
    } else {
      throw Exception(data['error'] ?? 'Error al registrar');
    }
  }

  // ── Login clásico ──────────────────────────────────────────────────────

  @override
  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.authUrl}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await saveToken(data['token']);
      await _saveRole(data['role'] ?? 'USER');
    } else {
      throw Exception(data['error'] ?? 'Error al iniciar sesión');
    }
  }

  // ── Login con Google (móvil) ───────────────────────────────────────────

  @override
  Future<void> loginWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Inicio de sesión cancelado');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('No se pudo obtener el token de Google');

    await loginWithGoogleToken(idToken);
  }

  // ── Enviar idToken al backend (web + móvil) ────────────────────────────

  @override
  Future<void> loginWithGoogleToken(String idToken) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.authUrl}/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await saveToken(data['token']);
      await _saveRole(data['role'] ?? 'USER');
    } else {
      throw Exception(data['error'] ?? 'Error al autenticar con Google');
    }
  }
  
  // ── Cambiar / Añadir contraseña ────────────────────────────────────────
  // currentPassword es null si la cuenta es Google y no tiene contraseña aún

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${ApiConstants.authUrl}/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (currentPassword != null) 'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error al cambiar contraseña');
    }
  }
  
}

  