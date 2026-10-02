import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'screens/new_password_screen.dart';
import 'services/crm_service.dart';
import 'services/notification_service.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('es');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await NotificationService.instance.init();

  runApp(const MiRedApp());
}

ThemeData _buildTheme() {
  const background = Color(0xFF17120F);
  const surface = Color(0xFF221B17);
  final scheme = ColorScheme.fromSeed(
    seedColor: gold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: gold,
    onPrimary: const Color(0xFF1E1606),
    surface: background,
    surfaceContainerLowest: background,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: const Color(0xFF2A221D),
    surfaceContainerHighest: const Color(0xFF332A24),
    outline: const Color(0xFF9C8F84),
    outlineVariant: const Color(0xFF3E342D),
  );
  final radius = BorderRadius.circular(16);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1D1713),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: gold, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
  );
}

class MiRedApp extends StatelessWidget {
  const MiRedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Red',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _syncedUser;

  /// true tras abrir el enlace de "recuperar contraseña" del correo: se pide
  /// la contraseña nueva antes de entrar a la app.
  bool _recovering = false;
  AuthState? _lastAuthState;

  /// Reprograma los avisos una vez por sesión iniciada.
  void _resyncNotifications(String userId) {
    if (_syncedUser == userId) return;
    _syncedUser = userId;
    CrmService(Supabase.instance.client)
        .fetchPendingReminders()
        .then(NotificationService.instance.resync)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Cada evento se procesa una sola vez: al reconstruir con el mismo
        // evento no se vuelve a pedir la contraseña.
        final state = snapshot.data;
        if (state != null && !identical(state, _lastAuthState)) {
          _lastAuthState = state;
          if (state.event == AuthChangeEvent.passwordRecovery) {
            _recovering = true;
          } else if (state.event == AuthChangeEvent.signedOut) {
            _recovering = false;
          }
        }
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        if (session != null && _recovering) {
          return NewPasswordScreen(
            fromRecovery: true,
            onDone: () => setState(() => _recovering = false),
          );
        }
        if (session != null) {
          _resyncNotifications(session.user.id);
          return const HomeShell();
        }
        _syncedUser = null;
        return const AuthScreen();
      },
    );
  }
}
