import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/whiteboard/whiteboard_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/auth/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/pairing',
      builder: (context, state) => const PairingScreen(),
    ),
    GoRoute(
      path: '/whiteboard/:sessionId/:role',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId'] ?? '';
        final role = state.pathParameters['role'] ?? 'student';
        return WhiteboardScreen(sessionId: sessionId, role: role);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
