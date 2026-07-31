import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// VIBER — Design Tokens
// ══════════════════════════════════════════════════════════════════════════════
// Colores FIJOS (igual en dark y light — nunca dependen del tema):
//   appAccent, appEnergy, appError, appSuccess y sus glows
//
// Colores ADAPTABLES (cambian con el tema):
//   Usar la extensión BuildContext: context.appBg, context.appSurface, etc.
//   Las constantes legacy (appBg, appSurface…) siguen existiendo con los
//   valores dark para no romper el código existente. Migralos gradualmente.
// ══════════════════════════════════════════════════════════════════════════════

// ── Paleta DARK — escala de elevación con matiz violeta. En dark la profundidad
//    viene de escalonar la LUMINOSIDAD: bg(~8%) < surface(~12%) < alt(~16%) < card2(~20%).
const Color appBg          = Color(0xFF0F0D14);   // fondo base (scaffold)
const Color appSurface     = Color(0xFF181421);   // barras (appbar/nav), paneles
const Color appSurfaceAlt  = Color(0xFF221C30);   // tarjetas elevadas, sheets
const Color appCard        = Color(0xFF181421);
const Color appCard2       = Color(0xFF2A2338);   // inputs, chips, elementos altos
const Color appTextPrim    = Color(0xFFF4F1F6);
const Color appTextSec     = Color(0xFFA89FB0);
const Color appTextDim     = Color(0xFF6E6678);
// Divisor/borde neutro translúcido. Gris-violeta: se ve sutil en oscuro Y en claro
// (antes era blanco translúcido → invisible sobre fondos claros).
const Color appDivider     = Color(0x2E7E7689);

/// Convierte un color hex ("#RRGGBB" o "RRGGBB") en [Color].
/// Devuelve null si la entrada es null o no es un hex válido — así el llamante
/// puede hacer `hexToColorOrNull(room.accentColor) ?? appAccent`.
Color? hexToColorOrNull(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}

// ── Paleta LIGHT (solo uso interno en ThemeData) ──────────────────────────────
// La "página" es un gris-violeta claro para que las tarjetas/barras BLANCAS
// resalten por valor (antes todo era casi blanco y no se separaba nada).
const Color _bgLight         = Color(0xFFEAE7F1);   // página (scaffold)
const Color _surfaceLight    = Color(0xFFFFFFFF);   // tarjetas, appbar, nav
const Color _surfaceAltLight = Color(0xFFE1DCEC);   // sheets, elevado
const Color _cardLight       = Color(0xFFFFFFFF);
const Color _card2Light      = Color(0xFFECE8F4);   // inputs, chips
const Color _textPrimLight   = Color(0xFF1A1620);
const Color _textSecLight    = Color(0xFF6E6678);
const Color _textDimLight    = Color(0xFFAEAAB2);
const Color _dividerLight    = Color(0x14000000);

// ── Acento principal — morado (botones y detalles). Tono claro para que se vea
//    sobre el fondo oscuro (el morado profundo se hundiría, ~2.4:1). ───────────
const Color appAccent      = Color(0xFFA062D6);
const Color appAccentGlow  = Color(0x24A062D6);
const Color appAccentDim   = Color(0x14A062D6);
/// Texto/iconos SOBRE el acento morado o el oro: el blanco contrasta flojo,
/// así que se usa un violeta casi negro (~5:1).
const Color appOnAccent    = Color(0xFF241636);

/// Acento para MODO CLARO: morado profundo. El lavanda `appAccent` se lee flojo
/// como texto sobre blanco (~3.4:1); este pasa ~5.8:1 y deja texto blanco nítido
/// en los botones. En oscuro se sigue usando `appAccent` (que es claro y resalta).
const Color _accentLight   = Color(0xFF7A3FB5);

// ── Acento energía — CORAL (rol único: "en directo" / actividad / oyentes).
//    Es un color del propio gradiente atardecer, así que armoniza con el morado
//    (el oro-limón anterior chocaba como warm suelto en campo frío).
const Color appEnergy      = Color(0xFFEC5C3E);
const Color appEnergyGlow  = Color(0x24EC5C3E);

// ── Marca secundaria — morado y magenta del gradiente atardecer ───────────────
const Color appPurple      = Color(0xFF6B3A94);
const Color appMagenta     = Color(0xFFB23B79);

// ── Estados semánticos — igual en ambos temas ─────────────────────────────────
const Color appSuccess     = Color(0xFF4ADE80);
const Color appError       = Color(0xFFE55353);

// ── Gradientes de marca ───────────────────────────────────────────────────────
// Cálido = energía/día/directo · Atardecer = noche/mood (gradiente principal).
const LinearGradient appWarmGradient = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [Color(0xFFFDE162), Color(0xFFF8A533), Color(0xFFF1793C), Color(0xFFE03E32)],
);
const LinearGradient appBrandGradient = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [Color(0xFFF8A533), Color(0xFFEC5C3E), Color(0xFFB23B79), Color(0xFF6B3A94)],
);

// ── Alias room (compatibilidad) ───────────────────────────────────────────────
const Color roomBg         = appBg;
const Color roomSurface    = appSurface;
const Color roomSurfaceAlt = appSurfaceAlt;
const Color roomAccent     = appAccent;
const Color roomAccentGlow = appAccentGlow;
const Color roomEnergy     = appEnergy;
const Color roomEnergyGlow = appEnergyGlow;
const Color roomTextPrim   = appTextPrim;
const Color roomTextSec    = appTextSec;
const Color roomDivider    = appDivider;

// ══════════════════════════════════════════════════════════════════════════════
// BuildContext extension — colores adaptables al tema actual
// ══════════════════════════════════════════════════════════════════════════════
// Úsalos en build(BuildContext context) como:
//   context.appSurface    context.appTextPrim    context.appDivider
// Los colores de acento/error/success son siempre const — no hacen falta en la ext.
// ══════════════════════════════════════════════════════════════════════════════
extension AppColorsX on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;

  Color get appBgColor         => _dark ? appBg          : _bgLight;
  Color get appSurfaceColor    => _dark ? appSurface      : _surfaceLight;
  Color get appSurfaceAltColor => _dark ? appSurfaceAlt   : _surfaceAltLight;
  Color get appCardColor       => _dark ? appCard         : _cardLight;
  Color get appCard2Color      => _dark ? appCard2        : _card2Light;
  Color get appTextPrimColor   => _dark ? appTextPrim     : _textPrimLight;
  Color get appTextSecColor    => _dark ? appTextSec      : _textSecLight;
  Color get appTextDimColor    => _dark ? appTextDim      : _textDimLight;
  Color get appDividerColor    => _dark ? appDivider      : _dividerLight;
  Color get appAccentGlowColor => _dark ? appAccentGlow   : const Color(0x1F7A3FB5);
  Color get appAccentDimColor  => _dark ? appAccentDim    : const Color(0x127A3FB5);

  /// Acento de marca, adaptable por modo: lavanda claro en oscuro, morado
  /// profundo en claro (para que se lea sobre fondos blancos).
  Color get appAccentColor     => _dark ? appAccent  : _accentLight;
  Color get appOnAccentColor   => _dark ? appOnAccent : Colors.white;
  Color get appEnergyColor     => appEnergy;
}

// ── Radios ────────────────────────────────────────────────────────────────────
const double radiusSm  = 8.0;
const double radiusMd  = 12.0;
const double radiusLg  = 16.0;
const double radiusXl  = 24.0;
const double radiusFull = 999.0;

// ── Espaciado ─────────────────────────────────────────────────────────────────
const double spacingXs = 4.0;
const double spacingSm = 8.0;
const double spacingMd = 16.0;
const double spacingLg = 24.0;
const double spacingXl = 32.0;

// ══════════════════════════════════════════════════════════════════════════════
// ThemeData — dark y light.  Úsalos en MaterialApp(theme:, darkTheme:, themeMode:)
// ══════════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  // ── Acceso unificado ──────────────────────────────────────────────────────
  /// Alias de darkTheme para retrocompatibilidad con código existente.
  static ThemeData get theme => darkTheme;

  // ── Tipografía: Fredoka (display) + Nunito (cuerpo/UI) ──────────────────────
  // El cuerpo y los labels heredan 'Nunito' del fontFamily del ThemeData.
  static TextTheme _textTheme(Color prim, Color sec) => TextTheme(
    displayLarge:   TextStyle(fontFamily: 'Fredoka', color: prim, fontWeight: FontWeight.w600),
    displayMedium:  TextStyle(fontFamily: 'Fredoka', color: prim, fontWeight: FontWeight.w600),
    displaySmall:   TextStyle(fontFamily: 'Fredoka', color: prim, fontWeight: FontWeight.w600),
    headlineLarge:  TextStyle(fontFamily: 'Fredoka', color: prim, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(fontFamily: 'Fredoka', color: prim, fontWeight: FontWeight.w600),
    headlineSmall:  TextStyle(fontFamily: 'Fredoka', color: prim, fontWeight: FontWeight.w500),
    titleLarge:     TextStyle(fontFamily: 'Fredoka', color: prim, fontWeight: FontWeight.w500),
    titleMedium:    TextStyle(color: prim, fontWeight: FontWeight.w600),
    titleSmall:     TextStyle(color: sec),
    bodyLarge:      TextStyle(color: prim),
    bodyMedium:     TextStyle(color: prim),
    bodySmall:      TextStyle(color: sec),
    labelLarge:     TextStyle(color: prim, fontWeight: FontWeight.w600),
    labelMedium:    TextStyle(color: sec),
    labelSmall:     TextStyle(color: sec),
  );

  // ── Tema OSCURO ───────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: appBg,
    colorScheme: const ColorScheme.dark(
      primary: appAccent,
      onPrimary: appOnAccent,
      secondary: appEnergy,
      onSecondary: appOnAccent,
      tertiary: appPurple,
      onTertiary: appTextPrim,
      surface: appSurface,
      onSurface: appTextPrim,
      surfaceContainerHighest: appCard2,
      error: appError,
      onError: appTextPrim,
    ),

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: appSurface,
      foregroundColor: appTextPrim,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: appTextPrim,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: appTextSec, size: 22),
      actionsIconTheme: IconThemeData(color: appTextSec, size: 22),
    ),

    // ── NavigationBar ────────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: appSurface,
      indicatorColor: appAccentGlow,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return TextStyle(
          color: active ? appAccent : appTextSec,
          fontSize: 11,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
            color: active ? appAccent : appTextSec, size: 22);
      }),
    ),

    // ── ElevatedButton ──────────────────────────────────────────────────────
    // Resuelve el problema de texto invisible: foregroundColor = appTextPrim
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: appAccent,
        foregroundColor: appOnAccent,   // ← marrón oscuro: contrasta sobre naranja
        disabledBackgroundColor: appAccent.withOpacity(0.4),
        disabledForegroundColor: appOnAccent.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        elevation: 0,
      ),
    ),

    // ── TextButton ──────────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: appAccent,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    // ── OutlinedButton ──────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: appAccent,
        side: const BorderSide(color: appAccent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    ),

    // ── TextField / Input ───────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: appCard2,
      hintStyle: const TextStyle(color: appTextSec, fontSize: 14),
      labelStyle: const TextStyle(color: appTextSec, fontSize: 14),
      prefixIconColor: appTextSec,
      suffixIconColor: appTextSec,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: appAccent.withOpacity(0.6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: appError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: appError, width: 1.5),
      ),
    ),

    // ── Card ─────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: appCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: appDivider),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── ListTile ─────────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: appTextPrim,
      iconColor: appTextSec,
    ),

    // ── Divider ──────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: appDivider,
      thickness: 1,
      space: 1,
    ),

    // ── FloatingActionButton ─────────────────────────────────────────────────
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: appAccent,
      foregroundColor: appOnAccent,  // ← marrón oscuro sobre naranja
      elevation: 4,
    ),

    // ── SnackBar ─────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: appCard2,
      contentTextStyle: const TextStyle(color: appTextPrim),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Chip ─────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: appCard2,
      selectedColor: appAccent.withOpacity(0.25),
      labelStyle: const TextStyle(color: appTextSec, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: appAccent, fontSize: 13),
      side: const BorderSide(color: appDivider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),

    // ── Dialog ───────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: appSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
      titleTextStyle: const TextStyle(
        color: appTextPrim,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(color: appTextSec, fontSize: 14),
    ),

    // ── ProgressIndicator ────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: appAccent,
    ),

    // ── Texto global ─────────────────────────────────────────────────────────
    textTheme: _textTheme(appTextPrim, appTextSec),
  );

  // ── Tema CLARO ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: _bgLight,
    colorScheme: const ColorScheme.light(
      primary: _accentLight,
      onPrimary: Colors.white,
      secondary: appEnergy,
      onSecondary: appOnAccent,
      tertiary: appPurple,
      onTertiary: Colors.white,
      surface: _surfaceLight,
      onSurface: _textPrimLight,
      surfaceContainerHighest: _surfaceAltLight,
      error: appError,
      onError: Colors.white,
    ),

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: _surfaceLight,
      foregroundColor: _textPrimLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Color(0x14000000),
      titleTextStyle: TextStyle(
        color: _textPrimLight,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: _textSecLight, size: 22),
      actionsIconTheme: IconThemeData(color: _textSecLight, size: 22),
    ),

    // ── NavigationBar ────────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surfaceLight,
      indicatorColor: const Color(0x1F7A3FB5),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return TextStyle(
          color: active ? _accentLight : _textSecLight,
          fontSize: 11,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(color: active ? _accentLight : _textSecLight, size: 22);
      }),
    ),

    // ── ElevatedButton ──────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentLight,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _accentLight.withOpacity(0.4),
        disabledForegroundColor: Colors.white.withOpacity(0.6),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        elevation: 0,
      ),
    ),

    // ── TextButton ──────────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _accentLight,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    // ── OutlinedButton ──────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _accentLight,
        side: const BorderSide(color: _accentLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
    ),

    // ── TextField / Input ───────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceAltLight,
      hintStyle: const TextStyle(color: _textSecLight, fontSize: 14),
      labelStyle: const TextStyle(color: _textSecLight, fontSize: 14),
      prefixIconColor: _textSecLight,
      suffixIconColor: _textSecLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: appAccent.withOpacity(0.6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: appError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: appError, width: 1.5),
      ),
    ),

    // ── Card ─────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: _cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: _dividerLight),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── ListTile ─────────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: _textPrimLight,
      iconColor: _textSecLight,
    ),

    // ── Divider ──────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: _dividerLight,
      thickness: 1,
      space: 1,
    ),

    // ── FloatingActionButton ─────────────────────────────────────────────────
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _accentLight,
      foregroundColor: Colors.white,
      elevation: 4,
    ),

    // ── SnackBar ─────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _textPrimLight,
      contentTextStyle: const TextStyle(color: _bgLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Chip ─────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: _card2Light,
      selectedColor: _accentLight.withOpacity(0.15),
      labelStyle: const TextStyle(color: _textSecLight, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: _accentLight, fontSize: 13),
      side: const BorderSide(color: _dividerLight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),

    // ── Dialog ───────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: _surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg)),
      titleTextStyle: const TextStyle(
        color: _textPrimLight,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(color: _textSecLight, fontSize: 14),
    ),

    // ── ProgressIndicator ────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _accentLight),

    // ── Texto global ─────────────────────────────────────────────────────────
    textTheme: _textTheme(_textPrimLight, _textSecLight),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets reutilizables del sistema de diseño
// ══════════════════════════════════════════════════════════════════════════════

/// Botón primario de ancho completo — reemplaza el ElevatedButton hardcoded
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimary),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// Campo de texto estándar — reemplaza los TextField hardcodeados.
/// Cuando [obscureText] es true, muestra automáticamente un icono de ojo
/// para alternar la visibilidad de la contraseña.
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    _hidden = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _hidden,
      textInputAction: widget.textInputAction,
      style: TextStyle(color: context.appTextPrimColor),
      onSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: appTextSec,
                ),
                tooltip: _hidden ? 'auth.show_password'.tr() : 'auth.hide_password'.tr(),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

/// Tarjeta de superficie estándar
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(spacingMd),
      decoration: BoxDecoration(
        color: context.appSurfaceColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: appAccent.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }
}

/// Banner de error estándar
class AppErrorBanner extends StatelessWidget {
  final String message;

  const AppErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(spacingMd),
      decoration: BoxDecoration(
        color: appError.withOpacity(0.12),
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: appError.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: appError, size: 18),
          const SizedBox(width: spacingSm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: appError, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Imagotipo de la app: isotipo (muñequito) + wordmark "VIBER" con el
/// gradiente de marca. Usa [showWordmark]: false para mostrar solo el isotipo.
class AppLogo extends StatelessWidget {
  final double size;          // altura del isotipo en px
  final bool showWordmark;

  const AppLogo({super.key, this.size = 84, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/isotipo.png',
          height: size,
          filterQuality: FilterQuality.medium,
        ),
        if (showWordmark) ...[
          SizedBox(height: size * 0.16),
          ShaderMask(
            shaderCallback: (rect) => appBrandGradient.createShader(rect),
            blendMode: BlendMode.srcIn,
            child: Text(
              'VIBER',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: size * 0.6,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Colors.white,   // lo pinta el shader
              ),
            ),
          ),
        ],
      ],
    );
  }
}