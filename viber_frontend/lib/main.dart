import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viber/core/ads/ad_service.dart';
import 'package:viber/core/theme/app_theme.dart';
import 'package:viber/core/theme/theme_provider.dart';
import 'package:viber/core/services/notification_service.dart';
import 'package:viber/core/services/push_notification_service.dart';
import 'package:viber/core/widgets/connection_banner.dart';
import 'features/auth/infrastructure/auth_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/rooms/presentation/active_room_provider.dart';
import 'app_shell.dart';
import 'home_screen.dart';

import 'features/auth/presentation/google_sign_in_web_helper.dart'
    if (dart.library.io) 'features/auth/presentation/google_sign_in_web_helper_stub.dart';

/// Key global del ScaffoldMessenger: permite mostrar notificaciones push en
/// primer plano como SnackBar desde fuera del árbol de widgets.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (kIsWeb) {
    await initGoogleSignInWeb();
  }

  NotificationService.loadPreferences();

  // Inicializa Firebase Cloud Messaging (solo móvil; no-op en web/escritorio).
  await PushNotificationService.instance.initFirebase();
  PushNotificationService.instance.attachMessenger(scaffoldMessengerKey);

  // Inicializa AdMob (solo móvil; no-op en web/escritorio).
  await AdService.instance.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('es'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('es'),
      child: const ViberApp(),
    ),
  );
}

/// Widget raíz de la aplicación.
/// Configura providers globales (ActiveRoomProvider, ThemeProvider),
/// localización (EasyLocalization) y el MaterialApp con temas claro/oscuro.
class ViberApp extends StatelessWidget {
  const ViberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ActiveRoomProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'Viber',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme:      AppTheme.lightTheme,
          darkTheme:  AppTheme.darkTheme,
          themeMode:  themeProvider.mode,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          // Respeta el tamaño de texto del sistema pero lo acota a un rango
          // seguro: con tamaños fijos en la UI, escalas extremas romperían
          // layouts. [0.9, 1.3] da accesibilidad sin desbordes.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler
                    .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
              ),
              child: ConnectionBanner(child: child!),
            );
          },
          home: const AppRouter(),
        ),
      ),
    );
  }
}

/// Enrutador inicial que decide qué pantalla mostrar según el estado de sesión.
/// Comprueba si hay un token JWT almacenado; si lo hay navega a HomeScreen,
/// si no muestra LoginScreen. Gestiona la transición login → registro → home.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  final _authService = AuthService();
  String _screen = 'splash';

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await _authService.isLoggedIn();
    if (loggedIn) PushNotificationService.instance.registerForUser();
    setState(() => _screen = loggedIn ? 'home' : 'login');
  }

  @override
  Widget build(BuildContext context) {
    switch (_screen) {
      case 'splash':
        return const _SplashView();

      case 'login':
        return LoginScreen(
          onGoToRegister: () => setState(() => _screen = 'register'),
          onLoginSuccess: () {
            PushNotificationService.instance.registerForUser();
            setState(() => _screen = 'home');
          },
        );

      case 'register':
        return RegisterScreen(
          onGoToLogin: () => setState(() => _screen = 'login'),
          onRegisterSuccess: () {
            PushNotificationService.instance.registerForUser();
            setState(() => _screen = 'home');
          },
        );

      case 'home':
        // AppShell envuelve HomeScreen con el Stack del mini-player
        return AppShell(
          child: HomeScreen(
            onLogout: () async {
              context.read<ActiveRoomProvider>().leaveRoom();
              await PushNotificationService.instance.unregister();
              await _authService.logout();
              if (mounted) {
                setState(() => _screen = 'login');
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        );

      default:
        return const SizedBox();
    }
  }
}

/// Pantalla de arranque: el logo "respira" suavemente mientras se comprueba la
/// sesión, en lugar de quedarse estático junto a un spinner frío.
class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Animation<double> _scale =
      Tween(begin: 0.97, end: 1.04).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Scaffold(
      backgroundColor: appBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            reduceMotion
                ? const AppLogo(size: 96)
                : ScaleTransition(scale: _scale, child: const AppLogo(size: 96)),
            const SizedBox(height: 40),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: appAccent),
            ),
          ],
        ),
      ),
    );
  }
}