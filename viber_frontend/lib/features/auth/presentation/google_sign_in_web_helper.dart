// Helper web — inicializa Google Sign-In y expone el stream de idTokens
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web_plugin;

const _clientId =
    '1000375197009-qkdrlcn486egpq8tqt1sl88r3l25nge2.apps.googleusercontent.com';

// Stream público al que se suscriben las pantallas
final _idTokenController = StreamController<String>.broadcast();
Stream<String> get googleWebIdTokenStream => _idTokenController.stream;

final _googleSignIn = GoogleSignIn(
  clientId: _clientId,
  scopes: ['email', 'profile'],
);

bool _initialized = false;

/// Inicializar una sola vez — llamar en main() antes de runApp()
Future<void> initGoogleSignInWeb() async {
  if (_initialized) return;
  _initialized = true;

  try {
    // Inicializar el plugin directamente — este sí funciona
    final plugin =
        GoogleSignInPlatform.instance as web_plugin.GoogleSignInPlugin;
    await plugin.init(clientId: _clientId);
  } catch (e) {
    // Si init falla, continuar igualmente (el meta tag puede haberlo inicializado)
  }

  // Escuchar cambios de usuario
  _googleSignIn.onCurrentUserChanged.listen((account) async {
    if (account == null) return;
    try {
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken != null) {
        _idTokenController.add(idToken);
      }
    } catch (_) {}
  });

  // Intentar restaurar sesión silenciosa
  _googleSignIn.signInSilently().catchError((_) {});
}

/// Suscribirse al stream de idTokens
StreamSubscription<String> subscribeGoogleWebSignIn(
    void Function(String idToken) onIdToken) {
  return googleWebIdTokenStream.listen(onIdToken);
}

/// Cancelar suscripción (alias por compatibilidad)
void unsubscribeGoogleWebSignIn() {}