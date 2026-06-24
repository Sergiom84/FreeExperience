import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_direction.dart';

abstract final class AppTheme {
  static ThemeData forDirection(DesignDirection direction) =>
      switch (direction) {
        DesignDirection.umbral => _build(
          brightness: Brightness.dark,
          background: const Color(0xFF080B0F),
          surface: const Color(0xFF141A21),
          foreground: const Color(0xFFF4EFE6),
          muted: const Color(0xFFAAA397),
          accent: const Color(0xFFC6A15B),
          focusRing: const Color(0x2EC6A15B),
          display: GoogleFonts.cormorantGaramondTextTheme,
          body: GoogleFonts.manropeTextTheme,
          radius: 8,
        ),
        DesignDirection.materia => _build(
          brightness: Brightness.dark,
          background: const Color(0xFF17130F),
          surface: const Color(0xFF241D17),
          foreground: const Color(0xFFF2E8DA),
          muted: const Color(0xFFB7A58F),
          accent: const Color(0xFFBE7C56),
          focusRing: const Color(0x2EBE7C56),
          display: GoogleFonts.frauncesTextTheme,
          body: GoogleFonts.sourceSans3TextTheme,
          radius: 18,
        ),
        DesignDirection.mineral => _build(
          brightness: Brightness.light,
          background: const Color(0xFFE9E5DC),
          surface: const Color(0xFFF3F0E9),
          foreground: const Color(0xFF181A1B),
          muted: const Color(0xFF6E6A63),
          accent: const Color(0xFF8A6A3E),
          focusRing: const Color(0x288A6A3E),
          display: GoogleFonts.instrumentSerifTextTheme,
          body: GoogleFonts.dmSansTextTheme,
          radius: 2,
        ),
      };

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color foreground,
    required Color muted,
    required Color accent,
    required Color focusRing,
    required TextTheme Function([TextTheme?]) display,
    required TextTheme Function([TextTheme?]) body,
    required double radius,
  }) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final bodyTheme = body(
      base.textTheme,
    ).apply(bodyColor: foreground, displayColor: foreground);
    final displayTheme = display(
      base.textTheme,
    ).apply(bodyColor: foreground, displayColor: foreground);
    final textTheme = bodyTheme.copyWith(
      displayLarge: displayTheme.displayLarge?.copyWith(
        fontSize: 52,
        height: 0.96,
        fontWeight: FontWeight.w500,
      ),
      displayMedium: displayTheme.displayMedium?.copyWith(
        fontSize: 42,
        height: 1,
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: displayTheme.headlineLarge?.copyWith(
        fontSize: 31,
        height: 1.04,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: displayTheme.headlineMedium?.copyWith(
        fontSize: 25,
        height: 1.08,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: displayTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: bodyTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: bodyTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: bodyTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: bodyTheme.bodySmall?.copyWith(color: muted, fontSize: 12),
      labelLarge: bodyTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: bodyTheme.labelMedium?.copyWith(color: muted),
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: brightness == Brightness.dark ? background : Colors.white,
      secondary: accent,
      onSecondary: background,
      error: const Color(0xFFB86F6F),
      onError: Colors.white,
      surface: surface,
      onSurface: foreground,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      textTheme: textTheme,
      focusColor: focusRing,
      dividerColor: foreground.withValues(alpha: 0.12),
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: foreground.withValues(alpha: 0.1)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: background,
        indicatorColor: accent.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? accent : muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? accent : muted, size: 21);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          backgroundColor: accent,
          foregroundColor: brightness == Brightness.dark
              ? background
              : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: foreground,
          side: BorderSide(color: foreground.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: foreground.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: foreground.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: accent),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radius + 12),
          ),
        ),
      ),
    );
  }
}
