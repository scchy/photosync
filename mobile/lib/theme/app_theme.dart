import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// PhotoSync 设计系统 v2
/// Material 3 + 慷慨间距 + 清洁层级 + 高可读性
class AppTheme {
  // === 核心颜色 ===
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLightColor = Color(0xFF3B82F6);
  static const Color primaryDarkColor = Color(0xFF1D4ED8);
  static const Color onPrimaryColor = Colors.white;

  static const Color secondaryColor = Color(0xFF10B981);
  static const Color onSecondaryColor = Colors.white;

  /// 背景色 — 轻微暖灰，减少 sterile flat 感
  static const Color backgroundColor = Color(0xFFF8F9FB);
  static const Color surfaceColor = Color(0xFFFFFFFF);

  /// Surface 层次（M3 Tonal Palette）
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F5F9);
  static const Color surfaceContainer = Color(0xFFE2E8F0);
  static const Color surfaceContainerHigh = Color(0xFFD1D9E0);
  static const Color surfaceContainerHighest = Color(0xFFC1CBD5);

  /// 文字色
  static const Color textPrimaryColor = Color(0xFF0F172A);
  static const Color textSecondaryColor = Color(0xFF475569);
  static const Color textLightColor = Color(0xFF94A3B8);

  /// 分割线 / Outline
  static const Color dividerColor = Color(0xFFE2E8F0);
  static const Color outlineColor = Color(0xFFCBD5E1);
  static const Color outlineVariantColor = Color(0xFFE2E8F0);

  /// 状态色
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);

  // === 间距系统（慷慨）===
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacing2XL = 48.0;
  static const double spacing3XL = 64.0;

  // === 圆角系统 ===
  static const double smallRadius = 8.0;
  static const double mediumRadius = 12.0;
  static const double largeRadius = 16.0;
  static const double pillRadius = 9999.0;

  // === 阴影系统 ===
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12.0,
      offset: Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x12000000),
      blurRadius: 20.0,
      offset: Offset(0, 4),
      spreadRadius: -4,
    ),
  ];

  // === 动画 ===
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 200);
  static const Duration slowDuration = Duration(milliseconds: 300);

  static const Curve easeOutCubic = Cubic(0.16, 1, 0.3, 1);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // === 完整 M3 ColorScheme ===
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: onPrimaryColor,
        primaryContainer: Color(0xFFDBEAFE),
        onPrimaryContainer: primaryDarkColor,
        secondary: secondaryColor,
        onSecondary: onSecondaryColor,
        secondaryContainer: Color(0xFFD1FAE5),
        onSecondaryContainer: Color(0xFF065F46),
        surface: surfaceColor,
        onSurface: textPrimaryColor,
        onSurfaceVariant: textSecondaryColor,
        error: errorColor,
        onError: Colors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFF991B1B),
        outline: outlineColor,
        outlineVariant: outlineVariantColor,
        shadow: Color(0x1A000000),
        surfaceContainerLowest: surfaceContainerLowest,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
      ),
      scaffoldBackgroundColor: backgroundColor,
      // === Typography（Inter + 清晰层级 + 可读性优先）===
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              letterSpacing: -0.03,
              height: 1.1,
            ) ??
            const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              letterSpacing: -0.03,
              height: 1.1,
            ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              letterSpacing: -0.02,
              height: 1.15,
            ) ??
            const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textPrimaryColor,
              letterSpacing: -0.02,
              height: 1.15,
            ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
              letterSpacing: -0.01,
              height: 1.2,
            ) ??
            const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
              letterSpacing: -0.01,
              height: 1.2,
            ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
              letterSpacing: -0.01,
              height: 1.3,
            ) ??
            const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
              letterSpacing: -0.01,
              height: 1.3,
            ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
              letterSpacing: -0.01,
              height: 1.3,
            ) ??
            const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
              letterSpacing: -0.01,
              height: 1.3,
            ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ) ??
            const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ) ??
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textPrimaryColor,
              height: 1.6,
            ) ??
            const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textPrimaryColor,
              height: 1.6,
            ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: textSecondaryColor,
              height: 1.55,
            ) ??
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: textSecondaryColor,
              height: 1.55,
            ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: textLightColor,
              height: 1.45,
            ) ??
            const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: textLightColor,
              height: 1.45,
            ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
              letterSpacing: 0.01,
            ) ??
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
              letterSpacing: 0.01,
            ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondaryColor,
              letterSpacing: 0.02,
            ) ??
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondaryColor,
              letterSpacing: 0.02,
            ),
      ),
      // === AppBar ===
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.02,
        ),
      ),
      // === Card ===
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(largeRadius),
        ),
      ),
      // === ElevatedButton ===
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mediumRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.01,
          ),
        ),
      ),
      // === OutlinedButton ===
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mediumRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // === TextButton ===
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      // === InputDecoration ===
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: textLightColor,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: textSecondaryColor,
        ),
      ),
      // === Divider ===
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: spacingMD,
      ),
      // === NavigationBar (M3) ===
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        indicatorColor: primaryColor.withValues(alpha: 0.1),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillRadius),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? primaryColor : textLightColor,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? primaryColor : textLightColor,
            size: 24,
          );
        }),
        height: 72,
      ),
      // === BottomSheet ===
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(largeRadius)),
        ),
      ),
      // === Dialog ===
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(largeRadius),
        ),
      ),
      // === SnackBar ===
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimaryColor,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(mediumRadius)),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(spacingMD),
      ),
      // === Switch ===
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return surfaceContainer;
        }),
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      // === ListTile ===
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingSM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(mediumRadius),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondaryColor,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: onPrimaryColor,
        surface: Color(0xFF1E293B),
        onSurface: Colors.white,
        outline: Color(0xFF475569),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
    );
  }
}
