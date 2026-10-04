import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The same brand as the website and admin: warm paper, near-black ink,
/// photographs carry the colour. A serif for display, square controls.
abstract final class AppColors {
  static const paper = Color(0xFFF6F2EB);
  static const raised = Color(0xFFFBF9F5);
  static const sunken = Color(0xFFEDE7DD);
  static const photo = Color(0xFFE7E0D5);
  static const line = Color(0xFFE0D8CB);
  static const lineStrong = Color(0xFFC9BFAE);
  static const ink = Color(0xFF1D1B18);
  static const inkSoft = Color(0xFF4A463F);
  static const muted = Color(0xFF857E73);
  static const accent = Color(0xFF8E3B2A);
  static const success = Color(0xFF4C6747);
}

TextStyle display(double size, {FontWeight weight = FontWeight.w400, Color color = AppColors.ink, FontStyle style = FontStyle.normal}) =>
    GoogleFonts.cormorantGaramond(fontSize: size, fontWeight: weight, color: color, fontStyle: style, height: 1.05, letterSpacing: -size * 0.005);

/// Small uppercase label, as on the website.
TextStyle eyebrow({Color color = AppColors.muted}) =>
    GoogleFonts.instrumentSans(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 1.8, color: color);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
  final text = GoogleFonts.instrumentSansTextTheme(base.textTheme).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  const square = RoundedRectangleBorder();
  final label = GoogleFonts.instrumentSans(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 1.6);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: const ColorScheme.light(
      surface: AppColors.paper,
      surfaceContainer: AppColors.raised,
      surfaceContainerHigh: AppColors.raised,
      surfaceContainerHighest: AppColors.sunken,
      primary: AppColors.ink,
      onPrimary: AppColors.paper,
      secondary: AppColors.ink,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.lineStrong,
      outlineVariant: AppColors.line,
      error: AppColors.accent,
    ),
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: display(24, weight: FontWeight.w500),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.raised,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.instrumentSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.ink : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.ink : AppColors.muted, size: 22),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.25),
        disabledForegroundColor: AppColors.paper,
        minimumSize: const Size(64, 54),
        shape: square,
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink),
        minimumSize: const Size(64, 50),
        shape: square,
        textStyle: label,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft)),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.raised,
      labelStyle: TextStyle(color: AppColors.inkSoft),
      border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.lineStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.lineStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.ink, width: 1.2)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.paper,
      selectedColor: AppColors.ink,
      side: const BorderSide(color: AppColors.lineStrong),
      shape: square,
      labelStyle: GoogleFonts.instrumentSans(fontSize: 13, color: AppColors.ink),
      secondaryLabelStyle: GoogleFonts.instrumentSans(fontSize: 13, color: AppColors.paper),
      checkmarkColor: AppColors.paper,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: square,
        selectedBackgroundColor: AppColors.ink,
        selectedForegroundColor: AppColors.paper,
        side: const BorderSide(color: AppColors.lineStrong),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: GoogleFonts.instrumentSans(color: AppColors.paper),
      behavior: SnackBarBehavior.floating,
      shape: square,
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.paper, surfaceTintColor: Colors.transparent, shape: square),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.paper, surfaceTintColor: Colors.transparent, shape: square),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.ink),
  );
}
