import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/theme/theme_provider.dart';
import 'package:viber/core/services/notification_service.dart';
import 'package:viber/core/widgets/app_snack_bar.dart';
import '../../auth/infrastructure/auth_service.dart';
import '../infrastructure/friendship_service.dart';
import '../domain/user_profile.dart';
import 'edit_profile_screen.dart';

/// Página de Ko-fi para apoyar el proyecto y cubrir los costes del servidor.
/// TODO: sustituir por el handle real cuando se cree la cuenta en ko-fi.com.
const String _kofiUrl = 'https://ko-fi.com/viber';

/// Pantalla de ajustes de la aplicación.
/// Permite cambiar el tema (claro/oscuro), activar/desactivar notificaciones,
/// gestionar la contraseña (o añadirla si la cuenta es de Google),
/// configurar la privacidad del perfil y cerrar sesión.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _friendService = FriendshipService();

  UserProfile? _profile;
  bool _loading        = true;
  bool _privacySaving  = false;

  bool _mentionSound = NotificationService.mentionSoundEnabled;
  bool _notifSound   = NotificationService.notificationSoundEnabled;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _friendService.getMe();
      if (mounted) setState(() { _profile = p; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: appAccent))
          : ListView(
              children: [
                // ── Cuenta ──────────────────────────────────────────────
                _SectionHeader(title: 'settings.account_section'.tr()),
                _SettingsTile(
                  icon: Icons.person_outlined,
                  title: 'settings.edit_profile'.tr(),
                  subtitle: _profile?.username ?? '',
                  onTap: _profile == null
                      ? () {}
                      : () async {
                          final updated = await Navigator.push<UserProfile>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditProfileScreen(profile: _profile!),
                            ),
                          );
                          if (updated != null && mounted) {
                            setState(() => _profile = updated);
                          }
                        },
                ),

                const SizedBox(height: spacingSm),

                // ── Seguridad ────────────────────────────────────────────
                _SectionHeader(title: 'settings.security_section'.tr()),
                _SettingsTile(
                  icon: Icons.lock_outlined,
                  title: _profile?.authProvider == 'GOOGLE'
                      ? 'settings.add_password'.tr()
                      : 'settings.change_password'.tr(),
                  subtitle: _profile?.authProvider == 'GOOGLE'
                      ? 'settings.google_auth_hint'.tr()
                      : 'settings.password_hint'.tr(),
                  onTap: () => _showChangePasswordSheet(),
                ),

                const SizedBox(height: spacingSm),

                // ── Privacidad ───────────────────────────────────────────
                _SectionHeader(title: 'settings.privacy_section'.tr()),
                _SettingsToggleTile(
                  icon:     Icons.visibility_off_outlined,
                  title:    'settings.hide_profile'.tr(),
                  subtitle: 'settings.hide_profile_desc'.tr(),
                  value:    _profile?.profileHidden ?? false,
                  saving:   _privacySaving,
                  onChanged: _profile == null ? null : _toggleProfileHidden,
                ),

                const SizedBox(height: spacingSm),

                // ── Notificaciones ───────────────────────────────────────
                _SectionHeader(title: 'settings.notifications_section'.tr()),
                _SettingsToggleTile(
                  icon:     Icons.alternate_email_rounded,
                  title:    'settings.mention_sound'.tr(),
                  subtitle: 'settings.mention_sound_desc'.tr(),
                  value:    _mentionSound,
                  onChanged: (v) {
                    setState(() => _mentionSound = v);
                    NotificationService.mentionSoundEnabled = v;
                  },
                ),
                _SettingsToggleTile(
                  icon:     Icons.notifications_outlined,
                  title:    'settings.notif_sound'.tr(),
                  subtitle: 'settings.notif_sound_desc'.tr(),
                  value:    _notifSound,
                  onChanged: (v) {
                    setState(() => _notifSound = v);
                    NotificationService.notificationSoundEnabled = v;
                  },
                ),

                const SizedBox(height: spacingSm),

                // ── Apariencia ───────────────────────────────────────────
                _SectionHeader(title: 'settings.appearance_section'.tr()),
                _ThemeSelector(
                  current: themeProvider.mode,
                  onChanged: (mode) => themeProvider.setMode(mode),
                ),

                const SizedBox(height: spacingSm),

                // ── Idioma ───────────────────────────────────────────────
                _SectionHeader(title: 'settings.language_section'.tr()),
                const _LanguageSelector(),

                const SizedBox(height: spacingSm),

                // ── Apoya el proyecto ────────────────────────────────────
                _SectionHeader(title: 'settings.support_section'.tr()),
                _SettingsTile(
                  icon: Icons.favorite_rounded,
                  iconColor: appAccent,
                  title: 'settings.support_kofi'.tr(),
                  subtitle: 'settings.support_kofi_desc'.tr(),
                  onTap: _openKofi,
                ),

                const SizedBox(height: spacingSm),

                // ── Zona peligrosa ───────────────────────────────────────
                _SectionHeader(title: 'settings.danger_section'.tr()),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'settings.logout'.tr(),
                  iconColor: appError,
                  titleColor: appError,
                  showChevron: false,
                  onTap: _confirmLogout,
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  title: 'settings.delete_account'.tr(),
                  subtitle: 'settings.delete_account_warning'.tr(),
                  iconColor: appError,
                  titleColor: appError,
                  enabled: false,
                  showChevron: false,
                  onTap: () {},
                ),

                const SizedBox(height: spacingXl),
              ],
            ),
    );
  }

  // ── Ocultar / mostrar perfil ─────────────────────────────────────────────

  Future<void> _toggleProfileHidden(bool value) async {
    setState(() => _privacySaving = true);
    try {
      final updated = await _friendService.updatePrivacy(hidden: value);
      if (mounted) setState(() => _profile = updated);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _privacySaving = false);
    }
  }

  // ── Cambiar / Añadir contraseña ──────────────────────────────────────────

  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
      ),
      builder: (_) => _ChangePasswordSheet(
        isGoogleAccount: _profile?.authProvider == 'GOOGLE',
        authService: _authService,
        onSuccess: () {
          _loadProfile();
          _showSnack('settings.password_updated'.tr());
        },
      ),
    );
  }

  // ── Cerrar sesión ────────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.logout_title'.tr()),
        content: Text('settings.logout_confirmation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('settings.logout'.tr(),
                style: const TextStyle(color: appError)),
          ),
        ],
      ),
    );
    if (ok == true) widget.onLogout();
  }

  // ── Apoyar el proyecto (Ko-fi) ───────────────────────────────────────────

  Future<void> _openKofi() async {
    final uri = Uri.parse(_kofiUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showSnack('settings.support_error'.tr(), error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) =>
      AppSnackBar.show(context, msg, error: error);
}

// ── Selector de tema (Dark / Light / Sistema) ────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      (mode: ThemeMode.dark,   icon: Icons.dark_mode_rounded,      label: 'settings.dark_mode'.tr()),
      (mode: ThemeMode.light,  icon: Icons.light_mode_rounded,     label: 'settings.light_mode'.tr()),
      (mode: ThemeMode.system, icon: Icons.brightness_auto_rounded, label: 'settings.system_mode'.tr()),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: 10),
      child: Row(
        children: options.map((opt) {
          final selected = current == opt.mode;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ThemeOption(
                icon: opt.icon,
                label: opt.label,
                selected: selected,
                onTap: () => onChanged(opt.mode),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? appAccent.withOpacity(0.12)
              : context.appCard2Color,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(
            color: selected ? appAccent : appDivider,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? appAccent : context.appTextSecColor,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? appAccent : context.appTextSecColor,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet: Cambiar / Añadir contraseña ──────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  final bool isGoogleAccount;
  final AuthService authService;
  final VoidCallback onSuccess;

  const _ChangePasswordSheet({
    required this.isGoogleAccount,
    required this.authService,
    required this.onSuccess,
  });

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'auth.password_too_short'.tr());
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'auth.passwords_mismatch'.tr());
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await widget.authService.changePassword(
        currentPassword: widget.isGoogleAccount ? null : _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          spacingXl, spacingLg, spacingXl, spacingXl + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: spacingLg),
              decoration: BoxDecoration(
                color: context.appDividerColor,
                borderRadius: BorderRadius.circular(radiusFull),
              ),
            ),
          ),

          Text(
            widget.isGoogleAccount
                ? 'settings.add_password_title'.tr()
                : 'settings.change_password_title'.tr(),
            style: TextStyle(
              color: context.appTextPrimColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: spacingXs),
          Text(
            widget.isGoogleAccount
                ? 'settings.add_password_explanation'.tr()
                : 'settings.change_password_explanation'.tr(),
            style: TextStyle(color: context.appTextSecColor, fontSize: 13),
          ),
          const SizedBox(height: spacingLg),

          if (_error != null) ...[
            AppErrorBanner(message: _error!),
            const SizedBox(height: spacingMd),
          ],

          if (!widget.isGoogleAccount) ...[
            AppTextField(
              controller: _currentCtrl,
              label: 'settings.current_password'.tr(),
              prefixIcon: Icons.lock_outline,
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: spacingMd),
          ],

          AppTextField(
            controller: _newCtrl,
            label: 'settings.new_password'.tr(),
            prefixIcon: Icons.lock_rounded,
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: spacingMd),

          AppTextField(
            controller: _confirmCtrl,
            label: 'settings.confirm_new_password'.tr(),
            prefixIcon: Icons.lock_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
          const SizedBox(height: spacingLg),

          AppPrimaryButton(
            label: widget.isGoogleAccount
                ? 'settings.add_password'.tr()
                : 'common.save'.tr(),
            icon: Icons.save_rounded,
            isLoading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

// ── Selector de idioma ───────────────────────────────────────────────────────
//
// Tile único que abre un bottom-sheet con la lista completa.
// Añadir un idioma nuevo = una línea en [_languages]. La página de ajustes
// nunca crece independientemente del número de idiomas disponibles.

class _LanguageSelector extends StatelessWidget {
  // ↓ Ampliar aquí para añadir más idiomas
  static const _languages = [
    (locale: Locale('es'), flag: '🇪🇸', key: 'settings.language_es'),
    (locale: Locale('en'), flag: '🇬🇧', key: 'settings.language_en'),
  ];

  const _LanguageSelector();

  // Devuelve la entrada correspondiente al locale activo
  static ({Locale locale, String flag, String key}) _current(Locale active) =>
      _languages.firstWhere(
        (l) => l.locale == active,
        orElse: () => _languages.first,
      );

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
      ),
      builder: (sheetCtx) {
        final active = sheetCtx.locale;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: spacingMd),
                decoration: BoxDecoration(
                  color: sheetCtx.appDividerColor,
                  borderRadius: BorderRadius.circular(radiusFull),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    spacingMd, 0, spacingMd, spacingXs),
                child: Text(
                  'settings.language_section'.tr(),
                  style: TextStyle(
                    color: sheetCtx.appTextPrimColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              ..._languages.map((opt) {
                final selected = active == opt.locale;
                return Material(
                  color: sheetCtx.appCardColor,
                  child: InkWell(
                    onTap: () {
                      sheetCtx.setLocale(opt.locale);
                      Navigator.pop(sheetCtx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: spacingMd, vertical: 14),
                      child: Row(
                        children: [
                          Text(opt.flag,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: spacingMd),
                          Expanded(
                            child: Text(
                              opt.key.tr(),
                              style: TextStyle(
                                color: selected
                                    ? appAccent
                                    : sheetCtx.appTextPrimColor,
                                fontSize: 15,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_rounded,
                                color: appAccent, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: spacingSm),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current(context.locale);
    return Material(
      color: context.appCardColor,
      child: InkWell(
        onTap: () => _openPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: spacingMd, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: context.appCard2Color,
                  borderRadius: BorderRadius.circular(radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(cur.flag,
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings.language_section'.tr(),
                      style: TextStyle(
                        color: context.appTextPrimColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cur.key.tr(),
                      style: TextStyle(
                          color: context.appTextDimColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: context.appTextDimColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets de soporte ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(spacingMd, spacingLg, spacingMd, spacingXs),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: context.appTextDimColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ── Toggle tile (switch) ────────────────────────────────────────────────────

class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  subtitle;
  final bool     value;
  final bool     saving;
  final void Function(bool)? onChanged;

  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.saving   = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: context.appCard2Color,
                borderRadius: BorderRadius.circular(radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: context.appTextSecColor, size: 18),
            ),
            const SizedBox(width: spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.appTextPrimColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(color: context.appTextDimColor, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (saving)
              const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: appAccent, strokeWidth: 2),
              )
            else
              Switch(
                value:              value,
                onChanged:          onChanged,
                activeColor:        appAccent,
                inactiveThumbColor: context.appTextDimColor,
                inactiveTrackColor: context.appCard2Color,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Tile normal (navegación) ─────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final bool enabled;
  final bool showChevron;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.enabled = true,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: Material(
        color: context.appCardColor,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: context.appCard2Color,
                    borderRadius: BorderRadius.circular(radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: iconColor ?? context.appTextSecColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor ?? context.appTextPrimColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(color: context.appTextDimColor, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showChevron && enabled)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.appTextDimColor,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
