import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Beels design tokens (web parity).
class BeelsColors {
  BeelsColors._();

  static const accent = Color(0xFF4F46E5);
  static const accentHover = Color(0xFF4338CA);
  static const accentSoft = Color(0xFFEEEDFB);
  static const surface = Color(0xFFFCFCFE);
  static const surfaceAlt = Color(0xFFF7F7FA);
  static const panel = Color(0xFFFFFFFF);
  static const fieldFill = Color(0xFFF4F4F8);
  static const border = Color(0xFFE3E3EA);
  static const borderStrong = Color(0xFFD5D5DF);
  static const ink0 = Color(0xFF21222D);
  static const ink1 = Color(0xFF5B5D6B);
  static const ink2 = Color(0xFF7B7D8C);
  static const ink3 = Color(0xFF9DA0AE);
  static const hint = Color(0xFF8A8C99);
  static const ok = Color(0xFF1F7A4D);
  static const okSoft = Color(0xFFEAF6F0);
  static const warn = Color(0xFFB0700F);
  static const warnSoft = Color(0xFFFBF3E4);
  static const err = Color(0xFFB23A3A);
  static const errSoft = Color(0xFFFBEDED);
}

/// Material 3 theme: Inter for body/labels, Bricolage Grotesque for headings.
ThemeData beelsTheme(BuildContext context) {
  final base = ThemeData(useMaterial3: true);

  final inter = GoogleFonts.interTextTheme(base.textTheme);
  final display = GoogleFonts.bricolageGrotesqueTextTheme(base.textTheme);
  final textTheme = display.copyWith(
    bodyLarge: inter.bodyLarge,
    bodyMedium: inter.bodyMedium,
    bodySmall: inter.bodySmall,
    labelLarge: inter.labelLarge,
    labelMedium: inter.labelMedium,
    labelSmall: inter.labelSmall,
  );

  final colorScheme = base.colorScheme.copyWith(
    primary: BeelsColors.accent,
    onPrimary: Colors.white,
    secondary: BeelsColors.accent,
    onSecondary: Colors.white,
    error: BeelsColors.err,
    surface: BeelsColors.surface,
    onSurface: BeelsColors.ink0,
    outline: BeelsColors.borderStrong,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: BeelsColors.surface,
    textTheme: textTheme,
    textSelectionTheme:
        const TextSelectionThemeData(cursorColor: BeelsColors.accent),
    appBarTheme: AppBarTheme(
      backgroundColor: BeelsColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: BeelsColors.ink0,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: BeelsColors.ink0,
      ),
    ),
    cardTheme: CardTheme(
      color: BeelsColors.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BeelsColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BeelsColors.fieldFill,
      hintStyle: textTheme.bodyMedium?.copyWith(color: BeelsColors.hint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BeelsColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: BeelsColors.err, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: BeelsColors.surfaceAlt,
      selectedColor: BeelsColors.accentSoft,
      side: const BorderSide(color: BeelsColors.border),
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: textTheme.labelMedium?.copyWith(color: BeelsColors.ink1),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BeelsColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: BeelsColors.accentSoft,
        disabledForegroundColor: BeelsColors.ink2,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BeelsColors.accent,
        side: const BorderSide(color: BeelsColors.borderStrong),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BeelsColors.accent,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BeelsColors.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: BeelsColors.accentSoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? BeelsColors.accent
              : BeelsColors.ink2,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? BeelsColors.ink0
              : BeelsColors.ink2,
        ),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: BeelsColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: BeelsColors.ink0,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: BeelsColors.panel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: BeelsColors.borderStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BeelsColors.ink0,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(
      color: BeelsColors.border,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BeelsColors.accent,
      linearTrackColor: BeelsColors.border,
    ),
  );
}
