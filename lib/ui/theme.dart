import 'package:flutter/material.dart';

import '../analysis/analyzer.dart';

/// Colours and type: a dark, sporty look with the desktop app's green.
class Fa {
  static const bg = Color(0xFF0B1220);
  static const surface = Color(0xFF131C2E);
  static const surface2 = Color(0xFF1B2740);
  static const border = Color(0xFF26324D);
  static const ink = Color(0xFFF1F5F9);
  static const ink2 = Color(0xFFA9B6CC);
  static const ink3 = Color(0xFF7C8AA5);
  static const green = Color(0xFF22C55E);
  static const greenSoft = Color(0xFF12301F);
  static const red = Color(0xFFEF4444);
  static const yellow = Color(0xFFFACC15);
  static const blue = Color(0xFF60A5FA);

  static Color tone(Tone t) => switch (t) {
        Tone.good => green,
        Tone.warn => yellow,
        Tone.bad => red,
        Tone.info => ink,
        Tone.muted => ink3,
      };

  /// Score colours, as in the desktop report.
  static Color score(int s) => s >= 75 ? green : (s >= 60 ? const Color(0xFFF59E0B) : red);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: green, secondary: blue, surface: surface, error: red),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0, centerTitle: true),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: const Color(0xFF052E16),
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: border, width: 2),
          textStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: green, thumbColor: green, inactiveTrackColor: border),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? green : ink3),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? greenSoft : surface2),
      ),
    );
  }

  static BoxDecoration card({Color? border}) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border ?? Fa.border, width: 1.5),
      );
}
