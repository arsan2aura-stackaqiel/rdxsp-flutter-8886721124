import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'admin_page.dart';
import 'owner_page.dart';
import 'landing.dart';
import 'intro_carousel.dart';
import 'music_player.dart';

class _C {
  static const bg        = Color(0xFF050A12);
  static const surface   = Color(0xFF0A1525);
  static const card      = Color(0xFF0E1E35);
  static const border    = Color(0xFF162B4A);
  static const borderLit = Color(0xFF1E3F6E);
  static const steel     = Color(0xFF1A4F8A);
  static const blueLight = Color(0xFF4A94E8);
  static const chrome    = Color(0xFF7AB4E8);
  static const frost     = Color(0xFFADD4F5);
  static const green     = Color(0xFF22C55E);
  static const red       = Color(0xFFEF4444);
  static const text      = Color(0xFFDEEEFB);
  static const textSub   = Color(0xFF6A92B8);
  static const textDim   = Color(0xFF2E4E6E);
}

class _AppTheme {
  static const _font = 'ShareTechMono';

  static ThemeData build() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _font,
    scaffoldBackgroundColor: _C.bg,

    colorScheme: const ColorScheme.dark(
      brightness:             Brightness.dark,
      primary:                _C.blueLight,
      onPrimary:              _C.bg,
      primaryContainer:       _C.steel,
      onPrimaryContainer:     _C.frost,
      secondary:              _C.chrome,
      onSecondary:            _C.bg,
      secondaryContainer:     _C.borderLit,
      onSecondaryContainer:   _C.text,
      tertiary:               _C.green,
      onTertiary:             _C.bg,
      error:                  _C.red,
      onError:                _C.text,
      surface:                _C.surface,
      onSurface:              _C.text,
      outline:                _C.border,
      outlineVariant:         _C.borderLit,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: _C.surface,
      foregroundColor: _C.text,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w600,
        color: _C.text, letterSpacing: 0.4,
      ),
      iconTheme: IconThemeData(color: _C.chrome, size: 22),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _C.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return _C.border;
          if (s.contains(WidgetState.pressed)) return _C.steel;
          return _C.blueLight;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return _C.textDim;
          return _C.bg;
        }),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: _font, fontSize: 14,
              fontWeight: FontWeight.w600, letterSpacing: 0.8),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.blueLight, width: 1.5),
      ),
    ),
  );
}

Route<dynamic>? _generateRoute(RouteSettings settings) {
  final args = settings.arguments as Map<String, dynamic>?;

  Widget page;

  switch (settings.name) {
    case '/':
      page = const LandingPage();
      break;

    case '/login':
      page = const LoginPage();
      break;

    case '/intro':
      page = const IntroCarouselPage();
      break;

    case '/music':
      page = const MusicPlayerPage();
      break;

    case '/dashboard':
      // Pakai FutureBuilder untuk baca session dari SharedPreferences
      page = const _DashboardLoader();
      break;

    case '/home':
      if (args == null) {
        page = const _NotFoundPage(routeName: '/home (missing args)');
      } else {
        page = HomePage(
          username:    args['username']    as String? ?? 'User',
          password:    args['password']    as String? ?? '',
          role:        args['role']        as String? ?? 'member',
          expiredDate: args['expiredDate'] as String? ?? '-',
          sessionKey:  args['sessionKey']  as String? ?? '-',
          listBug: List<Map<String, dynamic>>.from(args['listBug'] ?? []),
        );
      }
      break;

    case '/seller':
      if (args == null) {
        page = const _NotFoundPage(routeName: '/seller (missing args)');
      } else {
        page = SellerPage(keyToken: args['keyToken'] as String? ?? '-');
      }
      break;

    case '/admin':
      if (args == null) {
        page = const _NotFoundPage(routeName: '/admin (missing args)');
      } else {
        page = AdminPage(sessionKey: args['sessionKey'] as String? ?? '-');
      }
      break;

    case '/owner':
      if (args == null) {
        page = const _NotFoundPage(routeName: '/owner (missing args)');
      } else {
        page = OwnerPage(
          sessionKey: args['sessionKey'] as String? ?? '-',
          username:   args['username']   as String? ?? 'User',
        );
      }
      break;

    default:
      page = _NotFoundPage(routeName: settings.name ?? 'unknown');
  }

  return PageRouteBuilder<dynamic>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final inCurve  = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic);

      return FadeTransition(
        opacity: inCurve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(inCurve),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.82).animate(outCurve),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 0.97).animate(outCurve),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD LOADER — baca session dari SharedPreferences
// ═══════════════════════════════════════════════════════════════════════════
class _DashboardLoader extends StatefulWidget {
  const _DashboardLoader();

  @override
  State<_DashboardLoader> createState() => _DashboardLoaderState();
}

class _DashboardLoaderState extends State<_DashboardLoader> {
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    List<dynamic> safeDecode(String key) {
      try {
        return jsonDecode(prefs.getString(key) ?? '[]') as List<dynamic>;
      } catch (_) {
        return [];
      }
    }

    final session = {
      'username':    prefs.getString('username')    ?? 'User',
      'password':    prefs.getString('password')    ?? '',
      'role':        prefs.getString('role')        ?? 'member',
      'expiredDate': prefs.getString('expiredDate') ?? '-',
      'key':         prefs.getString('key')         ?? '-',
      'listBug':     safeDecode('listBug'),
      'listDoos':    safeDecode('listDoos'),
      'news':        safeDecode('news'),
    };

    if (mounted) setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF050A12),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4A94E8)),
        ),
      );
    }

    return DashboardPage(
      username:    _session!['username']    as String,
      password:    _session!['password']    as String,
      role:        _session!['role']        as String,
      expiredDate: _session!['expiredDate'] as String,
      listBug:     List<Map<String, dynamic>>.from(_session!['listBug']  ?? []),
      listDoos:    List<Map<String, dynamic>>.from(_session!['listDoos'] ?? []),
      sessionKey:  _session!['key']         as String,
      news:        List<dynamic>.from(_session!['news'] ?? []),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 404 PAGE
// ═══════════════════════════════════════════════════════════════════════════
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({required this.routeName});
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_rounded, color: _C.textSub, size: 60),
            const SizedBox(height: 20),
            const Text('404', style: TextStyle(
                fontSize: 72, fontWeight: FontWeight.w800, color: _C.text, letterSpacing: -3)),
            const SizedBox(height: 10),
            const Text('Route not found', style: TextStyle(
                fontSize: 16, color: _C.textSub)),
            const SizedBox(height: 10),
            Text('"$routeName"', style: const TextStyle(color: _C.textDim, fontSize: 12)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    statusBarBrightness:               Brightness.dark,
    systemNavigationBarColor:          _C.bg,
    systemNavigationBarDividerColor:   Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const _OrcaApp());
}

class _OrcaApp extends StatelessWidget {
  const _OrcaApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CRASH LIGHT',
      theme: _AppTheme.build(),
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
    );
  }
}