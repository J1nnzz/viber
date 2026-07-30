import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../infrastructure/auth_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/widgets/motion.dart';
import 'google_sign_in_button.dart';

import 'google_sign_in_web_helper.dart'
    if (dart.library.io) 'google_sign_in_web_helper_stub.dart';

/// Pantalla de inicio de sesión con username/contraseña o Google Sign-In.
/// En web usa el flujo Google One Tap (google_sign_in_web_helper.dart).
class LoginScreen extends StatefulWidget {
  final VoidCallback onGoToRegister;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.onGoToRegister,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading       = false;
  bool _isGoogleLoading = false;
  String? _error;
  StreamSubscription<String>? _googleSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _googleSub = subscribeGoogleWebSignIn(_onWebIdToken);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _googleSub?.cancel();
    super.dispose();
  }

  Future<void> _onWebIdToken(String idToken) async {
    if (!mounted) return;
    setState(() { _isGoogleLoading = true; _error = null; });
    try {
      await _authService.loginWithGoogleToken(idToken);
      if (mounted) widget.onLoginSuccess();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      widget.onLoginSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogleMobile() async {
    setState(() { _isGoogleLoading = true; _error = null; });
    try {
      await _authService.loginWithGoogle();
      widget.onLoginSuccess();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg != 'Inicio de sesión cancelado') {
        setState(() => _error = msg);
      }
    } finally {
      setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(spacingXl),
          child: AppEntrance(
            offsetY: 24,
            duration: const Duration(milliseconds: 500),
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(),
                const SizedBox(height: spacingXs),
                Text('auth.login_subtitle'.tr(),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14)),
                const SizedBox(height: spacingXl),

                if (_error != null) ...[
                  FeedbackEntrance(
                    key: ValueKey(_error),
                    kind: FeedbackKind.error,
                    child: AppErrorBanner(message: _error!),
                  ),
                  const SizedBox(height: spacingMd),
                ],

                GoogleSignInButton(
                  isLoading: _isGoogleLoading,
                  onPressed: kIsWeb ? null : _loginWithGoogleMobile,
                ),
                const SizedBox(height: spacingLg),
                const OrDivider(),
                const SizedBox(height: spacingLg),

                AppTextField(
                  controller: _usernameController,
                  label: 'auth.username'.tr(),
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: spacingMd),
                AppTextField(
                  controller: _passwordController,
                  label: 'auth.password'.tr(),
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _login,
                ),
                const SizedBox(height: spacingLg),

                AppPrimaryButton(
                  label: 'auth.login_button'.tr(),
                  icon: Icons.login_rounded,
                  isLoading: _isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: spacingMd),

                TextButton(
                  onPressed: widget.onGoToRegister,
                  child: Text('auth.register_link'.tr()),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}