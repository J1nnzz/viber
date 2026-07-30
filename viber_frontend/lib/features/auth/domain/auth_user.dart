/// Modelo mínimo del usuario autenticado: solo username y rol.
/// Se obtiene decodificando el JWT o consultando /api/auth/me.
class AuthUser {
  final String username;
  final String role;

  const AuthUser({required this.username, required this.role});

  bool get isAdmin => role == 'ADMIN';
}
