import 'package:flutter/material.dart';

/// Identidade visual do app: azul-marinho como cor principal, manga como
/// destaque e coral para ofertas, sobre um fundo creme. As cores foram
/// escolhidas à mão e conferidas para contraste de texto (WCAG AA).
abstract final class AppColors {
  static const navy = Color(0xFF172554);
  static const mango = Color(0xFFF59E0B);
  static const coral = Color(0xFFC2410C);
  static const cream = Color(0xFFFBF8F3);
  static const success = Color(0xFF1F7A4D);
  static const successBright = Color(0xFF6EE7A8);
  static const warningBright = Color(0xFFFFC46B);
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.navy,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFDCE4FF),
  onPrimaryContainer: Color(0xFF0B1535),
  secondary: Color(0xFFB45309),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFFFE8B8),
  onSecondaryContainer: Color(0xFF4A2C00),
  tertiary: AppColors.coral,
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFFFDBCB),
  onTertiaryContainer: Color(0xFF5A1800),
  error: Color(0xFFB3261E),
  onError: Colors.white,
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  surface: AppColors.cream,
  onSurface: Color(0xFF1C1B19),
  onSurfaceVariant: Color(0xFF4D4A44),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF6F1EA),
  surfaceContainer: Color(0xFFF0EAE1),
  surfaceContainerHigh: Color(0xFFEAE3D9),
  surfaceContainerHighest: Color(0xFFE3DCD1),
  outline: Color(0xFF7C776E),
  outlineVariant: Color(0xFFD5CEC2),
  inverseSurface: Color(0xFF31302D),
  onInverseSurface: Color(0xFFF4F0E9),
  inversePrimary: Color(0xFFAFC0FF),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFF5B544),
  onPrimary: Color(0xFF2A1800),
  primaryContainer: Color(0xFF2B3A7A),
  onPrimaryContainer: Color(0xFFDCE4FF),
  secondary: Color(0xFFAFC0FF),
  onSecondary: Color(0xFF0B1535),
  secondaryContainer: Color(0xFF26315F),
  onSecondaryContainer: Color(0xFFDCE4FF),
  tertiary: Color(0xFFFFB59A),
  onTertiary: Color(0xFF5A1800),
  tertiaryContainer: Color(0xFF7A2C0A),
  onTertiaryContainer: Color(0xFFFFDBCB),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  errorContainer: Color(0xFF8C1D18),
  onErrorContainer: Color(0xFFF9DEDC),
  surface: Color(0xFF12141C),
  onSurface: Color(0xFFE8E6E1),
  onSurfaceVariant: Color(0xFFC5C2BA),
  surfaceContainerLowest: Color(0xFF0D0F15),
  surfaceContainerLow: Color(0xFF1A1D27),
  surfaceContainer: Color(0xFF1F2230),
  surfaceContainerHigh: Color(0xFF292C3B),
  surfaceContainerHighest: Color(0xFF333748),
  outline: Color(0xFF948F86),
  outlineVariant: Color(0xFF454851),
  inverseSurface: Color(0xFFE8E6E1),
  onInverseSurface: Color(0xFF31302D),
  inversePrimary: AppColors.navy,
);

ThemeData _theme(ColorScheme scheme) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerLowest,
      side: BorderSide(color: scheme.outlineVariant),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

final ThemeData lightTheme = _theme(_lightScheme);
final ThemeData darkTheme = _theme(_darkScheme);

/// Cor própria de cada categoria, usada nos ícones de loja.
Color categoryColor(String category) {
  return switch (category) {
    'Alimentação' => const Color(0xFFD9480F),
    'Moda' => const Color(0xFFB0256E),
    'Calçados' => const Color(0xFF7048E8),
    'Eletrônicos' => const Color(0xFF1971C2),
    'Livros e Papelaria' => const Color(0xFF8F5B14),
    'Brinquedos' => const Color(0xFFD6336C),
    'Infantil' => const Color(0xFF0C8599),
    'Beleza' => const Color(0xFFAE3EC9),
    'Farmácia' => const Color(0xFF2B8A3E),
    'Ótica' => const Color(0xFF364FC7),
    'Casa e Decoração' => const Color(0xFF9C6A10),
    'Esportes' => const Color(0xFF087F5B),
    'Lazer' => const Color(0xFFC92A2A),
    'Estacionamento' => const Color(0xFF1D4ED8),
    _ => AppColors.navy,
  };
}
