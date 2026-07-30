abstract class AuthRepository {
  Future<void> register(String username, String email, String password);
  Future<void> login(String username, String password);
  Future<void> loginWithGoogle();
  Future<void> loginWithGoogleToken(String idToken);
  Future<void> changePassword({String? currentPassword, required String newPassword});
  Future<void> logout();
  Future<bool> isLoggedIn();
  Future<bool> isAdmin();
  Future<String?> getToken();
  Future<void> saveToken(String token);
}
