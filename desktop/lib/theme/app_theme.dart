import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PhotoSync 桌面端设计系统 v2
/// 基于 Premium Utilitarian Minimalism 理念
class AppTheme {
  // === 核心颜色 ===
  /// 画布/页面背景 - 暖骨白
  static const Color backgroundColor = Color(0xFFF7F6F3);

  /// 卡片/表面背景 - 纯白
  static const Color surfaceColor = Color(0xFFFFFFFF);

  /// 侧边栏背景
  static const Color sidebarColor = Color(0xFFF9F9F8);

  /// 主文字 - 深炭灰
  static const Color textPrimaryColor = Color(0xFF111111);

  /// 次要文字 - 暖灰
  static const Color textSecondaryColor = Color(0xFF787774);

  /// 极浅文字/禁用
  static const Color textLightColor = Color(0xFFADABA7);

  /// 分割线 - 极浅灰
  static const Color dividerColor = Color(0xFFEAEAEA);

  /// 强调色 - 深炭灰
  static const Color primaryColor = Color(0xFF111111);

  /// 强调色悬停
  static const Color primaryHoverColor = Color(0xFF333333);

  /// 成功色 - 柔和绿
  static const Color successColor = Color(0xFF346538);
  static const Color successBgColor = Color(0xFFEDF3EC);

  /// 错误色 - 柔和红
  static const Color errorColor = Color(0xFF9F2F2D);
  static const Color errorBgColor = Color(0xFFFDEBEC);

  /// 信息色 - 柔和蓝
  static const Color infoColor = Color(0xFF1F6C9F);
  static const Color infoBgColor = Color(0xFFE1F3FE);

  /// 警告色 - 柔和黄
  static const Color warningColor = Color(0xFF956400);
  static const Color warningBgColor = Color(0xFFFBF3DB);

  // === 间距系统 ===
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

  // === 阴影系统（极克制）===
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12.0,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 20.0,
      offset: Offset(0, 4),
    ),
  ];

  // === 边框系统 ===
  static const Border borderLight = Border.fromBorderSide(
    BorderSide(color: dividerColor, width: 1.0),
  );

  static RoundedRectangleBorder cardShape({double radius = mediumRadius}) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: dividerColor, width: 1.0),
    );
  }

  // === 动画 ===
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 200);
  static const Duration slowDuration = Duration(milliseconds: 300);

  static const Curve easeOutCubic = Cubic(0.16, 1, 0.3, 1);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: textSecondaryColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onError: Colors.white,
        onSurface: textPrimaryColor,
        onBackground: textPrimaryColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.02,
        ),
      ),
      // Card
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 0,
        shape: cardShape(radius: mediumRadius),
        margin: EdgeInsets.zero,
      ),
      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
          letterSpacing: -0.03,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
          letterSpacing: -0.02,
          height: 1.15,
        ),
        displaySmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.01,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.01,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.01,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimaryColor,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondaryColor,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textLightColor,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
          letterSpacing: 0.02,
        ),
      ),
      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(smallRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.01,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.12);
            }
            return null;
          }),
        ),
      ),
      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryColor,
          side: const BorderSide(color: dividerColor, width: 1.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(smallRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9F9F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          borderSide: const BorderSide(color: dividerColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          borderSide: const BorderSide(color: dividerColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          borderSide: const BorderSide(color: textPrimaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(
          fontSize: 14,
          color: textLightColor,
        ),
      ),
      // Divider
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: spacingMD,
      ),
      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(largeRadius),
        ),
      ),
      // List Tile
      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: spacingMD, vertical: spacingSM),
        minLeadingWidth: 40,
      ),
      // DataTable
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF9F9F8)),
        dataRowColor: WidgetStateProperty.all(surfaceColor),
        dividerThickness: 1,
        horizontalMargin: spacingMD,
        columnSpacing: spacingLG,
        headingTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondaryColor,
          letterSpacing: 0.02,
        ),
        dataTextStyle: const TextStyle(
          fontSize: 14,
          color: textPrimaryColor,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Color(0xFF111111),
        surface: Color(0xFF1C1C1C),
        background: Color(0xFF0A0A0A),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    );
  }
}
