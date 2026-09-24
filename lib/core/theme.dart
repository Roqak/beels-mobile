import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// One complete colour set. Light and dark palettes share the same roles.
class BeelsPalette {
  const BeelsPalette({
    required this.brightness,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.dye,
    required this.dyeMid,
    required this.dyeLine,
    required this.turmeric,
    required this.turmericSoft,
    required this.turmericInk,
    required this.surface,
    required this.surfaceAlt,
    required this.panel,
    required this.fieldFill,
    required this.border,
    required this.borderStrong,
    required this.ink0,
    required this.ink1,
    required this.ink2,
    required this.ink3,
    required this.hint,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.err,
    required this.errSoft,
  });

  final Brightness brightness;
  final Color accent,
      accentHover,
      accentSoft,
      dye,
      dyeMid,
      dyeLine,
      turmeric,
      turmericSoft,
      turmericInk,
      surface,
      surfaceAlt,
      panel,
      fieldFill,
      border,
      borderStrong,
      ink0,
      ink1,
      ink2,
      ink3,
      hint,
      ok,
      okSoft,
      warn,
      warnSoft,
      err,
      errSoft;

  // Adire palette: dyed indigo surfaces, live indigo actions, turmeric for
  // "your turn / next" moments only.
  static const light = BeelsPalette(
    brightness: Brightness.light,
    accent: Color(0xFF3D35CC),
    accentHover: Color(0xFF2F28A6),
    accentSoft: Color(0xFFECEBFB),
    dye: Color(0xFF17163F),
    dyeMid: Color(0xFF25236B),
    dyeLine: Color(0xFF5450C4),
    turmeric: Color(0xFFF0A81E),
    turmericSoft: Color(0xFFFCF1D8),
    turmericInk: Color(0xFF7A5200),
    surface: Color(0xFFFCFCFE),
    surfaceAlt: Color(0xFFF7F7FA),
    panel: Color(0xFFFFFFFF),
    fieldFill: Color(0xFFF4F4F8),
    border: Color(0xFFE3E3EA),
    borderStrong: Color(0xFFD5D5DF),
    ink0: Color(0xFF21222D),
    ink1: Color(0xFF5B5D6B),
    ink2: Color(0xFF6B6D7C),
    ink3: Color(0xFF6E7082),
    hint: Color(0xFF6B6D7C),
    ok: Color(0xFF1F7A4D),
    okSoft: Color(0xFFEAF6F0),
    warn: Color(0xFFB0700F),
    warnSoft: Color(0xFFFBF3E4),
    err: Color(0xFFB23A3A),
    errSoft: Color(0xFFFBEDED),
  );

  // Night: indigo-tinted near-black, raised panels one step lighter, the same
  // dye hero surfaces lifted so they still separate from the page.
  static const dark = BeelsPalette(
    brightness: Brightness.dark,
    accent: Color(0xFF7B74F7),
    accentHover: Color(0xFF8F89FF),
    accentSoft: Color(0xFF26244F),
    dye: Color(0xFF211F5C),
    dyeMid: Color(0xFF2C2A78),
    dyeLine: Color(0xFF6763D6),
    turmeric: Color(0xFFF0A81E),
    turmericSoft: Color(0xFF3A2E12),
    turmericInk: Color(0xFFF3C46B),
    surface: Color(0xFF11111B),
    surfaceAlt: Color(0xFF161622),
    panel: Color(0xFF1A1A27),
    fieldFill: Color(0xFF232332),
    border: Color(0xFF2C2C3D),
    borderStrong: Color(0xFF3B3B50),
    ink0: Color(0xFFF1F1F7),
    ink1: Color(0xFFBEBFD1),
    ink2: Color(0xFF9294A9),
    ink3: Color(0xFF6E7087),
    hint: Color(0xFF7C7E93),
    ok: Color(0xFF4FCB8B),
    okSoft: Color(0xFF14301F),
    warn: Color(0xFFE2A03F),
    warnSoft: Color(0xFF33270F),
    err: Color(0xFFF07676),
    errSoft: Color(0xFF361B1E),
  );
}

/// Beels design tokens. Read at build time from the active [BeelsPalette];
/// the app root calls [apply] when the system brightness changes.
class BeelsColors {
  BeelsColors._();

  static BeelsPalette _p = BeelsPalette.light;

  static void apply(Brightness brightness) {
    _p = brightness == Brightness.dark ? BeelsPalette.dark : BeelsPalette.light;
  }

  static Brightness get brightness => _p.brightness;

  static Color get accent => _p.accent;
  static Color get accentHover => _p.accentHover;
  static Color get accentSoft => _p.accentSoft;
  static Color get dye => _p.dye;
  static Color get dyeMid => _p.dyeMid;
  static Color get dyeLine => _p.dyeLine;
  static Color get turmeric => _p.turmeric;
  static Color get turmericSoft => _p.turmericSoft;
  static Color get turmericInk => _p.turmericInk;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get panel => _p.panel;
  static Color get fieldFill => _p.fieldFill;
  static Color get border => _p.border;
  static Color get borderStrong => _p.borderStrong;
  static Color get ink0 => _p.ink0;
  static Color get ink1 => _p.ink1;
  static Color get ink2 => _p.ink2;
  static Color get ink3 => _p.ink3;
  static Color get hint => _p.hint;
  static Color get ok => _p.ok;
  static Color get okSoft => _p.okSoft;
  static Color get warn => _p.warn;
  static Color get warnSoft => _p.warnSoft;
  static Color get err => _p.err;
  static Color get errSoft => _p.errSoft;
}

/// Material 3 theme: Inter for body/labels, Bricolage Grotesque for headings.
ThemeData beelsTheme(BuildContext context) {
  final isDark = BeelsColors.brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
  );

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
    textSelectionTheme: TextSelectionThemeData(cursorColor: BeelsColors.accent),
    appBarTheme: AppBarTheme(
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      backgroundColor: BeelsColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: BeelsColors.ink0,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
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
        side: BorderSide(color: BeelsColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BeelsColors.fieldFill,
      hintStyle: textTheme.bodyMedium?.copyWith(color: BeelsColors.hint),
      contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: BeelsColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: BeelsColors.err, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: BeelsColors.surfaceAlt,
      selectedColor: BeelsColors.accentSoft,
      side: BorderSide(color: BeelsColors.border),
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
        side: BorderSide(color: BeelsColors.borderStrong),
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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: BeelsPageTransitionsBuilder(),
        TargetPlatform.iOS: BeelsPageTransitionsBuilder(),
        TargetPlatform.linux: BeelsPageTransitionsBuilder(),
      },
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: BeelsColors.dye,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 3,
      extendedTextStyle:
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      shape: const StadiumBorder(),
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
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: BeelsColors.panel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: BeelsColors.borderStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BeelsColors.ink0,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: BeelsColors.border,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: BeelsColors.accent,
      linearTrackColor: BeelsColors.border,
    ),
  );
}

/// Fade + short rise. Quiet, fast (uses the route's duration), ease-out.
class BeelsPageTransitionsBuilder extends PageTransitionsBuilder {
  const BeelsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}
