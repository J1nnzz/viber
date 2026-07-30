// Implementación web — google_sign_in 6.3.0 + google_sign_in_web 0.12.4
import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web_only;
import 'package:viber/core/theme/app_theme.dart';

export 'or_divider.dart';
// Exportar también el helper para que login/register puedan suscribirse
export 'google_sign_in_web_helper.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final void Function(String idToken)? onWebCredential; // ignorado en web
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.onWebCredential,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _loadingButton(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: web_only.renderButton(
          configuration: web_only.GSIButtonConfiguration(
            theme: isDark
                ? web_only.GSIButtonTheme.filledBlack
                : web_only.GSIButtonTheme.outline,
            text: web_only.GSIButtonText.continueWith,
            shape: web_only.GSIButtonShape.rectangular,
            logoAlignment: web_only.GSIButtonLogoAlignment.left,
            minimumWidth: 400,
          ),
        ),
      );
    } catch (_) {
      return _loadingButton(context);
    }
  }

  Widget _loadingButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          backgroundColor: cs.surfaceContainerHighest,
          side: BorderSide(color: Theme.of(context).dividerColor, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd)),
        ),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.onSurface.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}
