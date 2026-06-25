import 'dart:ui';
import 'package:flutter/material.dart';

class AppTheme {
  // Primary Education Blue Brand Colors
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep Navy Blue
  static const Color accentBlue = Color(0xFF2563EB);  // Vivid Royal Blue
  static const Color lightBlue = Color(0xFFEFF6FF);   // Soft Ice Blue
  static const Color darkBlueBg = Color(0xFF0F172A);  // Rich Slate Black/Blue

  // Light Mode Color Scheme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentBlue,
      brightness: Brightness.light,
      primary: accentBlue,
      onPrimary: Colors.white,
      secondary: const Color(0xFF0D9488), // Teal
      background: const Color(0xFFF8FAFC), // Off-white
      surface: Colors.white,
      onBackground: const Color(0xFF0F172A),
      onSurface: const Color(0xFF0F172A),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      titleTextStyle: TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
  );

  // Dark Mode Color Scheme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentBlue,
      brightness: Brightness.dark,
      primary: accentBlue,
      onPrimary: Colors.white,
      secondary: const Color(0xFF14B8A6), // Teal
      background: darkBlueBg,
      surface: const Color(0xFF1E293B), // Slate Grey/Blue
      onBackground: const Color(0xFFF8FAFC),
      onSurface: const Color(0xFFF8FAFC),
    ),
    scaffoldBackgroundColor: darkBlueBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
      titleTextStyle: TextStyle(
        color: Color(0xFFF8FAFC),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
  );

  // Glassmorphic Container Decoration
  static BoxDecoration glassDecoration({
    required BuildContext context,
    double opacity = 0.1,
    double blur = 15.0,
    double borderRadius = 16.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.black : Colors.white;
    return BoxDecoration(
      color: baseColor.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        width: 1.0,
      ),
    );
  }
}

// Glassmorphism Widget Wrapper
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.opacity = 0.08,
    this.blur = 15.0,
    this.borderRadius = 16.0,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: AppTheme.glassDecoration(
            context: context,
            opacity: opacity,
            blur: blur,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
