import 'dart:async';

// Stub para móvil — las funciones no hacen nada en iOS/Android
Future<void> initGoogleSignInWeb() async {}
StreamSubscription<String> subscribeGoogleWebSignIn(void Function(String) onIdToken) {
  return const Stream<String>.empty().listen(onIdToken);
}
void unsubscribeGoogleWebSignIn() {}