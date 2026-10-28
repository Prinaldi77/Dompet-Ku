import 'package:flutter/material.dart';

/// Nilai palet mode terang. Dipakai sebagai sumber [AppPalette.light].
abstract final class AppColors {
  static const emerald = Color(0xFF0F766E);
  static const emeraldSoft = Color(0xFFE6F4F2);
  static const slate = Color(0xFF1E293B);
  static const background = Color(0xFFF8FAFC);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const income = Color(0xFF15803D);
  static const incomeTint = Color(0xFFE7F6EE);
  static const expense = Color(0xFFB91C1C);
  static const expenseTint = Color(0xFFFDECEC);
  static const warning = Color(0xFFB45309);
  static const warningTint = Color(0xFFFEF3C7);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.emerald,
    required this.emeraldSoft,
    required this.onAccent,
    required this.slate,
    required this.muted,
    required this.line,
    required this.background,
    required this.card,
    required this.income,
    required this.incomeTint,
    required this.expense,
    required this.expenseTint,
    required this.warning,
    required this.warningTint,
    required this.heroSurface,
    required this.onHero,
    required this.heroMuted,
  });

  /// Warna aksen utama (teks tombol, ikon aktif).
  final Color emerald;

  /// Latar lembut untuk chip/ikon aksen.
  final Color emeraldSoft;

  /// Teks/ikon di atas [emerald].
  final Color onAccent;

  /// Teks utama.
  final Color slate;

  /// Teks sekunder.
  final Color muted;

  /// Garis pemisah dan border kartu.
  final Color line;

  final Color background;

  /// Permukaan kartu, dialog, bottom sheet, dan input.
  final Color card;

  final Color income;
  final Color incomeTint;
  final Color expense;
  final Color expenseTint;
  final Color warning;
  final Color warningTint;

  /// Kartu kontras tinggi (saldo utama, ringkasan utang).
  final Color heroSurface;
  final Color onHero;
  final Color heroMuted;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  static const light = AppPalette(
    emerald: AppColors.emerald,
    emeraldSoft: AppColors.emeraldSoft,
    onAccent: Colors.white,
    slate: AppColors.slate,
    muted: AppColors.muted,
    line: AppColors.line,
    background: AppColors.background,
    card: Colors.white,
    income: AppColors.income,
    incomeTint: AppColors.incomeTint,
    expense: AppColors.expense,
    expenseTint: AppColors.expenseTint,
    warning: AppColors.warning,
    warningTint: AppColors.warningTint,
    heroSurface: AppColors.slate,
    onHero: Colors.white,
    heroMuted: Colors.white70,
  );

  static const dark = AppPalette(
    emerald: Color(0xFF2DD4BF),
    emeraldSoft: Color(0xFF12312F),
    onAccent: Color(0xFF04231F),
    slate: Color(0xFFE8EEF8),
    muted: Color(0xFF94A3B8),
    line: Color(0xFF263447),
    background: Color(0xFF0B1220),
    card: Color(0xFF121C2B),
    income: Color(0xFF4ADE80),
    incomeTint: Color(0xFF10291D),
    expense: Color(0xFFF87171),
    expenseTint: Color(0xFF33181B),
    warning: Color(0xFFFBBF24),
    warningTint: Color(0xFF33260D),
    heroSurface: Color(0xFF18263D),
    onHero: Color(0xFFF1F5F9),
    heroMuted: Color(0xFFCBD5E1),
  );

  @override
  AppPalette copyWith({
    Color? emerald,
    Color? emeraldSoft,
    Color? onAccent,
    Color? slate,
    Color? muted,
    Color? line,
    Color? background,
    Color? card,
    Color? income,
    Color? incomeTint,
    Color? expense,
    Color? expenseTint,
    Color? warning,
    Color? warningTint,
    Color? heroSurface,
    Color? onHero,
    Color? heroMuted,
  }) {
    return AppPalette(
      emerald: emerald ?? this.emerald,
      emeraldSoft: emeraldSoft ?? this.emeraldSoft,
      onAccent: onAccent ?? this.onAccent,
      slate: slate ?? this.slate,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      background: background ?? this.background,
      card: card ?? this.card,
      income: income ?? this.income,
      incomeTint: incomeTint ?? this.incomeTint,
      expense: expense ?? this.expense,
      expenseTint: expenseTint ?? this.expenseTint,
      warning: warning ?? this.warning,
      warningTint: warningTint ?? this.warningTint,
      heroSurface: heroSurface ?? this.heroSurface,
      onHero: onHero ?? this.onHero,
      heroMuted: heroMuted ?? this.heroMuted,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      emerald: mix(emerald, other.emerald),
      emeraldSoft: mix(emeraldSoft, other.emeraldSoft),
      onAccent: mix(onAccent, other.onAccent),
      slate: mix(slate, other.slate),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      background: mix(background, other.background),
      card: mix(card, other.card),
      income: mix(income, other.income),
      incomeTint: mix(incomeTint, other.incomeTint),
      expense: mix(expense, other.expense),
      expenseTint: mix(expenseTint, other.expenseTint),
      warning: mix(warning, other.warning),
      warningTint: mix(warningTint, other.warningTint),
      heroSurface: mix(heroSurface, other.heroSurface),
      onHero: mix(onHero, other.onHero),
      heroMuted: mix(heroMuted, other.heroMuted),
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}

ThemeData buildAppTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? AppPalette.light : AppPalette.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: p.emerald,
    brightness: brightness,
  ).copyWith(
    primary: p.emerald,
    onPrimary: p.onAccent,
    secondary: p.emerald,
    onSecondary: p.onAccent,
    surface: p.card,
    onSurface: p.slate,
    onSurfaceVariant: p.muted,
    outlineVariant: p.line,
    error: p.expense,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'PlusJakartaSans',
  );

  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    textTheme: base.textTheme.apply(
      bodyColor: p.slate,
      displayColor: p.slate,
    ),
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.slate,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: p.slate,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.emerald, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.emerald,
        foregroundColor: p.onAccent,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.emerald,
        side: BorderSide(color: p.emerald),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.emerald,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.emerald.withValues(alpha: 0.14),
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? p.emerald : p.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? p.emerald : p.muted,
          size: 24,
        );
      }),
    ),
    dividerColor: p.line,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? p.onHero
              : p.slate;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? p.heroSurface
              : p.card;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: p.line)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: p.muted),
  );
}
