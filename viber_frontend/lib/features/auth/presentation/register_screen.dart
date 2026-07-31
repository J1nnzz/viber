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

/// Pantalla de registro de nuevo usuario con username, email, contraseña y confirmación.
/// También permite registrarse directamente con Google Sign-In.
class RegisterScreen extends StatefulWidget {
  final VoidCallback onGoToLogin;
  final VoidCallback onRegisterSuccess;

  const RegisterScreen({
    super.key,
    required this.onGoToLogin,
    required this.onRegisterSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _googleSub?.cancel();
    super.dispose();
  }

  Future<void> _onWebIdToken(String idToken) async {
    if (!mounted) return;
    setState(() { _isGoogleLoading = true; _error = null; });
    try {
      await _authService.loginWithGoogleToken(idToken);
      if (mounted) widget.onRegisterSuccess();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _register() async {
    if (_passwordController.text.length < 6) {
      setState(() => _error = 'auth.password_too_short'.tr());
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'auth.passwords_mismatch'.tr());
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      await _authService.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
      widget.onRegisterSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerWithGoogleMobile() async {
    setState(() { _isGoogleLoading = true; _error = null; });
    try {
      await _authService.loginWithGoogle();
      widget.onRegisterSuccess();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg != 'errors.login_cancelled'.tr()) setState(() => _error = msg);
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
                Text('auth.register_title'.tr(),
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
                  onPressed: kIsWeb ? null : _registerWithGoogleMobile,
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
                  controller: _emailController,
                  label: 'auth.email'.tr(),
                  prefixIcon: Icons.email_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: spacingMd),
                AppTextField(
                  controller: _passwordController,
                  label: 'auth.password'.tr(),
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: spacingMd),
                AppTextField(
                  controller: _confirmController,
                  label: 'auth.confirm_password'.tr(),
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _register,
                ),
                const SizedBox(height: spacingLg),

                AppPrimaryButton(
                  label: 'auth.register_button'.tr(),
                  icon: Icons.person_add_outlined,
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: spacingMd),

                TextButton(
                  onPressed: widget.onGoToLogin,
                  child: Text('auth.login_link'.tr()),
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