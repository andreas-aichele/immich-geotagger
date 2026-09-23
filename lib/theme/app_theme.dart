import 'dart:math' as math;

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
  static const background = Color(0xFFFAFBFD);
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
      surfaceContainerLowest: background,
      surfaceContainerLow: const Color(0xFFF6F8FB),
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
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: const _LensPinPainter(),
      ),
    );
  }
}

class _LensPinPainter extends CustomPainter {
  const _LensPinPainter();

  static const _lavender = Color(0xFF9A91E9);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale, scale);

    final tile = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Radius.circular(22),
    );

    canvas.drawRRect(tile, Paint()..color = const Color(0xFFFCFDFE));
    canvas.save();
    canvas.clipRRect(tile);

    final peachWave = Path()
      ..moveTo(0, 64)
      ..cubicTo(18, 64, 30, 78, 49, 81)
      ..cubicTo(30, 84, 16, 91, 0, 96)
      ..close();
    canvas.drawPath(peachWave, Paint()..color = const Color(0xFFFFE9E5));

    final blueWave = Path()
      ..moveTo(42, 84)
      ..cubicTo(65, 82, 77, 61, 100, 57)
      ..lineTo(100, 82)
      ..cubicTo(77, 82, 64, 88, 42, 90)
      ..close();
    canvas.drawPath(blueWave, Paint()..color = const Color(0xFFE5F2FF));

    final mintWave = Path()
      ..moveTo(0, 96)
      ..cubicTo(29, 84, 55, 88, 100, 75)
      ..lineTo(100, 100)
      ..lineTo(0, 100)
      ..close();
    canvas.drawPath(mintWave, Paint()..color = const Color(0xFFDDF8F2));

    final pin = Path()
      ..moveTo(50, 12)
      ..cubicTo(31, 12, 18, 27, 18, 43)
      ..cubicTo(18, 62, 36, 74, 50, 87)
      ..cubicTo(64, 74, 82, 62, 82, 43)
      ..cubicTo(82, 27, 69, 12, 50, 12)
      ..close();

    canvas.drawShadow(pin, const Color(0x33000000), 2.5, false);

    canvas.save();
    canvas.clipPath(pin);
    canvas.drawRect(
      const Rect.fromLTWH(18, 12, 64, 32),
      Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.brandYellow, AppTheme.brandCoral],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(const Rect.fromLTWH(18, 12, 64, 32)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(18, 42, 32, 48),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF459EF8), Color(0xFF126FE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(18, 42, 32, 48)),
    );
    canvas.drawRect(
      const Rect.fromLTWH(50, 42, 32, 48),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF28C8B5), Color(0xFF078D9E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ).createShader(const Rect.fromLTWH(50, 42, 32, 48)),
    );
    canvas.restore();

    const apertureCenter = Offset(50, 37);
    const apertureRadius = 22.5;
    canvas.drawCircle(apertureCenter, apertureRadius + 2.5, Paint()..color = Colors.white);

    final apertureRect = Rect.fromCircle(center: apertureCenter, radius: 17.5);
    const segmentColors = [
      AppTheme.brandYellow,
      AppTheme.brandCoral,
      AppTheme.primary,
      AppTheme.brandTeal,
      Color(0xFF0AA398),
    ];
    const gap = 0.09;
    final segment = (math.pi * 2 / segmentColors.length) - gap;
    var angle = -math.pi * 0.78;
    for (final color in segmentColors) {
      canvas.drawArc(
        apertureRect,
        angle,
        segment,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9.5
          ..strokeCap = StrokeCap.round,
      );
      angle += segment + gap;
    }

    canvas.drawCircle(
      apertureCenter,
      9.6,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFF454A76), AppTheme.brandNavy, Color(0xFF15182E)],
        ).createShader(Rect.fromCircle(center: apertureCenter, radius: 9.6)),
    );
    canvas.drawCircle(const Offset(45.6, 32.8), 2.8, Paint()..color = _lavender.withValues(alpha: 0.82));
    canvas.drawCircle(const Offset(54.6, 41.1), 1.5, Paint()..color = _lavender.withValues(alpha: 0.65));

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LensPinPainter oldDelegate) => false;
}
