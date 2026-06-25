import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Wait for animation to finish
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    try {
      // Check authentication state
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;

      if (user != null) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    } catch (e) {
      debugPrint("Error checking auth state: $e. Defaulting to login.");
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.darkBlueBg, const Color(0xFF020617)]
                : [AppTheme.lightBlue, Colors.white],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Premium branding element
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentBlue.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.gesture_rounded,
                  size: 55,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Edu Board',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white : AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Smartphone. Your Whiteboard.',
                style: TextStyle(
                  fontSize: 16,
                  color: (isDark ? Colors.white70 : Colors.black54),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.accentBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
