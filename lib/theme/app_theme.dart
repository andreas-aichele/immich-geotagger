import 'package:flutter/material.dart';

class AppTheme {
  // Immich GeoTagger brand palette, derived from the Lens Pin mark.
  static const primary = Color(0xFF1E83F7);
  static const brandTeal = Color(0xFF13B8A6);
  static const brandCoral = Color(0xFFFF5269);
  static const brandYellow = Color(0xFFFFBE2E);
  static const brandNavy = Color(0xFF25284A);
  static const primarySoft = Color(0xFFF2F8FF);
  static const primarySoftStrong = Color(0xFFDCEEFF);
  static const tealSoft = Color(0xFFE8F8F5);
  static const coralSoft = Color(0xFFFFEEF1);
  static const yellowSoft = Color(0xFFFFF6DB);
  static const navySoft = Color(0xFFF0F0F6);
  static const ink = Color(0xFF2B2E46);
  static const muted = Color(0xFF6C7085);
  static const background = Colors.white;
  static const border = Color(0xFFE4E8EE);
  static const success = Color(0xFF0E8F7F);
  static const warning = Color(0xFF9B6A00);
  static const neutralMarker = Color(0xFF7C8191);

  static const brandGradient = LinearGradient(
    colors: [primary, brandTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: brandTeal,
      onSecondary: Colors.white,
      secondaryContainer: tealSoft,
      onSecondaryContainer: brandNavy,
      tertiary: brandCoral,
      onTertiary: Colors.white,
      tertiaryContainer: coralSoft,
      onTertiaryContainer: brandNavy,
      primaryContainer: primarySoft,
      onPrimaryContainer: primary,
      surface: Colors.white,
      onSurface: ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      outline: border,
      outlineVariant: const Color(0xFFEDF0F4),
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
        fillColor: const Color(0xFFF5F7FA),
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
          borderSide: const BorderSide(color: border),
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
          side: const BorderSide(color: primarySoftStrong),
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
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brandTeal : null,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? brandTeal : null,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? brandNavy : ink,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? tealSoft : Colors.white,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
        ),
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

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 44, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/brand_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
