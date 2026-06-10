import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.secondary,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.secondary,
        secondary: AppColors.gold,
        surface:   AppColors.surface,
        error:     AppColors.error,
      ),

      // Font global: Poppins
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge:  GoogleFonts.playfairDisplay(fontSize: 32, fontWeight: FontWeight.bold,  color: AppColors.white),
        displayMedium: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold,  color: AppColors.white),
        headlineLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.white),
        headlineMedium:GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.white),
        titleLarge:    GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.white),
        bodyLarge:     GoogleFonts.poppins(fontSize: 14, color: AppColors.lightGrey),
        bodyMedium:    GoogleFonts.poppins(fontSize: 12, color: AppColors.grey),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.white,
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Input / TextField
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: GoogleFonts.poppins(color: AppColors.grey),
        hintStyle:  GoogleFonts.poppins(color: AppColors.grey),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:     AppColors.surface,
        selectedItemColor:   AppColors.secondary,
        unselectedItemColor: AppColors.grey,
        type:                BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 0.5),

      // Global page transition — fade only (no slide).
      // Slide menyebabkan FAB terlihat "keluar dari screen" saat transisi.
      // FadeTransition menjaga semua widget (termasuk FAB) fade in place.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadePageTransitionsBuilder(),
          TargetPlatform.iOS: FadePageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Page transition that only fades — no slide.
///
/// Default [FadeUpwardsPageTransitionsBuilder] slides the exiting page,
/// causing elevated widgets (FAB, etc.) to briefly appear during exit
/// transitions. This builder eliminates the slide so all widgets
/// (including FAB) fade in place.
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ),
      child: child,
    );
  }
}
