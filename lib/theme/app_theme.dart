import 'package:flutter/material.dart';

class AppTheme {
  // Immich UI primary color.
  static const primary = Color(0xFF1E83F7);
  static const primarySoft = Color(0xFFF2F8FF);
  static const primarySoftStrong = Color(0xFFDCEEFF);
  static const ink = Color(0xFF333333);
  static const muted = Color(0xFF737373);
  static const background = Color(0xFFFAFAFA);
  static const border = Color(0xFFE5E5E5);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primarySoft,
      onPrimaryContainer: primary,
      surface: Colors.white,
      onSurface: ink,
      surfaceContainerLowest: background,
      surfaceContainerLow: const Color(0xFFF7F7F7),
      outline: border,
      outlineVariant: const Color(0xFFEDEDED),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
        prefixIconColor: const Color(0xFF666666),
        suffixIconColor: const Color(0xFF666666),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEAEAEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: Color(0xFFCFE6FF)),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primarySoftStrong,
      ),
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
