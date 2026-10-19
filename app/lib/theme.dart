import 'package:flutter/material.dart';

/// Palette lifted from the desert mood-diary mockup: teal sky fading to sand,
/// cream parchment cards, chunky brown outlines and an orange accent.
class Desert {
  static const skyTop = Color(0xFF3F9A8C);
  static const skyMid = Color(0xFF8CC3A0);
  static const sand = Color(0xFFEBD98E);
  static const sandDeep = Color(0xFFD9B95A);
  static const dune = Color(0xFFC99A45);
  static const cream = Color(0xFFFFF4BE);
  static const creamDeep = Color(0xFFF6E39A);
  static const outline = Color(0xFF5A3D25);
  static const bark = Color(0xFF4A3423);
  static const ink = Color(0xFF3B2A1A);
  static const inkSoft = Color(0xFF8A6E4B);
  static const orange = Color(0xFFF39A1F);
  static const mustard = Color(0xFFE6BF35);
  static const teal = Color(0xFF3FA38F);
  static const stone = Color(0xFFB9A88A);

  static const github = Color(0xFF24292F);
  static const health = Color(0xFFE5486B);

  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, sand],
    stops: [0, 0.45, 1],
  );
}

/// Rounded display face for numbers and titles; Nunito carries body text.
TextStyle display(double size, {Color color = Desert.ink, FontWeight weight = FontWeight.w700, List<Shadow>? shadows}) =>
    TextStyle(fontFamily: 'Fredoka', fontSize: size, fontWeight: weight, color: color, height: 1.05, shadows: shadows);

const titleShadow = [Shadow(color: Color(0x663B2A1A), offset: Offset(0, 3))];

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    colorScheme: ColorScheme.fromSeed(
      seedColor: Desert.orange,
      primary: Desert.orange,
      surface: Desert.cream,
      onSurface: Desert.ink,
    ),
    scaffoldBackgroundColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Desert.ink, displayColor: Desert.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      hintStyle: const TextStyle(color: Desert.inkSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Desert.creamDeep, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Desert.creamDeep, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Desert.orange, width: 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Desert.bark,
      contentTextStyle: TextStyle(color: Desert.cream, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Desert.orange,
      inactiveTrackColor: Desert.creamDeep,
      thumbColor: Desert.orange,
    ),
  );
}
