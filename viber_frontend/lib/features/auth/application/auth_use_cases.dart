import '../domain/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;
  LoginUseCase(this._repository);
  Future<void> call(String username, String password) =>
      _repository.login(username, password);
}

class RegisterUseCase {
  final AuthRepository _repository;
  RegisterUseCase(this._repository);
  Future<void> call(String username, String email, String password) =>
      _repository.register(username, email, password);
}

class LogoutUseCase {
  final AuthRepository _repository;
  LogoutUseCase(this._repository);
  Future<void> call() => _repository.logout();
}

class LoginWithGoogleUseCase {
  final AuthRepository _repository;
  LoginWithGoogleUseCase(this._repository);
  Future<void> call() => _repository.loginWithGoogle();
}

class LoginWithGoogleTokenUseCase {
  final AuthRepository _repository;
  LoginWithGoogleTokenUseCase(this._repository);
  Future<void> call(String idToken) => _repository.loginWithGoogleToken(idToken);
}

class ChangePasswordUseCase {
  final AuthRepository _repository;
  ChangePasswordUseCase(this._repository);
  Future<void> call({String? currentPassword, required String newPassword}) =>
      _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
}

class CheckAuthUseCase {
  final AuthRepository _repository;
  CheckAuthUseCase(this._repository);
  Future<bool> isLoggedIn() => _repository.isLoggedIn();
  Future<bool> isAdmin() => _repository.isAdmin();
  Future<String?> getToken() => _repository.getToken();
}
