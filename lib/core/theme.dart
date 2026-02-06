import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// GraphMeeting Fluent Design 主题系统
/// 
/// 设计参考：
/// - Windows 11 / WinUI 3
/// - Fluent Design System
/// - 亚克力材质、云母效果、揭示高光

/// 主题模式
enum AppThemeMode { light, dark, system }

/// GraphMeeting Fluent Design 主题系统
/// 
/// 设计参考：
/// - Windows 11 / WinUI 3
/// - Fluent Design System
/// - 默认深色主题（适合长时间会议场景）

class AppTheme {
  // ========== 响应式断点 ==========
  static const double breakpointMobile = 600;   // 手机
  static const double breakpointTablet = 900;   // 平板
  static const double breakpointDesktop = 1200; // 桌面
  
  // ========== 颜色系统 (深色模式默认) ==========
  
  // === 深色主题 ===
  static const Color darkBackgroundBase = Color(0xFF202020);      // 主背景
  static const Color darkBackgroundLayer = Color(0xFF2D2D2D);     // 卡片背景
  static const Color darkBackgroundAcrylic = Color(0xCC202020);   // 亚克力背景
  static const Color darkBackgroundSecondary = Color(0xFF3C3C3C); // 二级背景
  static const Color darkBackgroundTertiary = Color(0xFF4C4C4C);  // 三级背景
  
  static const Color darkTextPrimary = Color(0xE4FFFFFF);         // 90%白
  static const Color darkTextSecondary = Color(0x9EFFFFFF);       // 62%白
  static const Color darkTextTertiary = Color(0x61FFFFFF);        // 38%白
  static const Color darkTextDisabled = Color(0x42FFFFFF);        // 26%白
  
  static const Color darkBorderPrimary = Color(0x1AFFFFFF);       // 10%白
  static const Color darkBorderStrong = Color(0x33FFFFFF);        // 20%白
  
  // === 浅色主题 ===
  static const Color lightBackgroundBase = Color(0xFFF3F3F3);
  static const Color lightBackgroundLayer = Color(0xFFFFFFFF);
  static const Color lightBackgroundAcrylic = Color(0x80F3F3F3);
  static const Color lightBackgroundSecondary = Color(0xFFE8E8E8);
  static const Color lightBackgroundTertiary = Color(0xFFDDDDDD);
  
  static const Color lightTextPrimary = Color(0xE4000000);
  static const Color lightTextSecondary = Color(0x9E000000);
  static const Color lightTextTertiary = Color(0x61000000);
  static const Color lightTextDisabled = Color(0x42000000);
  
  static const Color lightBorderPrimary = Color(0x1A000000);
  static const Color lightBorderStrong = Color(0x33000000);
  
  // === 当前主题颜色（默认深色）===
  static Color get backgroundBase => _isDark ? darkBackgroundBase : lightBackgroundBase;
  static Color get backgroundLayer => _isDark ? darkBackgroundLayer : lightBackgroundLayer;
  static Color get backgroundAcrylic => _isDark ? darkBackgroundAcrylic : lightBackgroundAcrylic;
  static Color get backgroundSecondary => _isDark ? darkBackgroundSecondary : lightBackgroundSecondary;
  static Color get backgroundTertiary => _isDark ? darkBackgroundTertiary : lightBackgroundTertiary;
  
  static Color get textPrimary => _isDark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => _isDark ? darkTextSecondary : lightTextSecondary;
  static Color get textTertiary => _isDark ? darkTextTertiary : lightTextTertiary;
  static Color get textDisabled => _isDark ? darkTextDisabled : lightTextDisabled;
  static Color get textInverse => _isDark ? lightTextPrimary : darkTextPrimary;
  static Color get textPrimaryLight => darkTextPrimary; // 主要用于深色主题
  
  static Color get borderPrimary => _isDark ? darkBorderPrimary : lightBorderPrimary;
  static Color get borderStrong => _isDark ? darkBorderStrong : lightBorderStrong;
  
  // WinUI 强调色（深浅通用）
  static const Color accentPrimary = Color(0xFF4CC2FF);      // 亮蓝（深色模式优化）
  static const Color accentSecondary = Color(0xFF005FB8);    // 深蓝
  static const Color accentLight = Color(0xFF2D4A5E);        // 深色背景强调
  
  // 功能色
  static const Color success = Color(0xFF6CCB5F);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFFF5252);
  
  // 内部状态
  static bool _isDark = true; // 默认深色
  static bool get isDark => _isDark;
  static void setDark(bool value) => _isDark = value;

  // ========== 尺寸系统 ==========
  
  static const double radiusSm = 4.0;   // WinUI 小圆角
  static const double radiusMd = 4.0;   // WinUI 标准圆角
  static const double radiusLg = 8.0;   // WinUI 大圆角
  static const double radiusXl = 8.0;   // WinUI 超大圆角
  static const double radiusFull = 9999.0;

  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 20.0;
  static const double space2xl = 24.0;

  // ========== Fluent Design 效果 ==========
  
  /// 亚克力材质效果
  static BoxDecoration acrylic({
    Color? tintColor,
    double tintOpacity = 0.85,
    double blurAmount = 16.0,
  }) {
    final baseColor = tintColor ?? backgroundLayer;
    return BoxDecoration(
      color: baseColor.withOpacity(tintOpacity),
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(
        color: borderPrimary,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
  
  /// 云母效果 (Mica)
  static BoxDecoration mica({
    Color? baseColor,
  }) {
    return BoxDecoration(
      color: baseColor ?? backgroundBase,
      borderRadius: BorderRadius.circular(radiusMd),
    );
  }
  
  /// 卡片样式
  static BoxDecoration card({
    bool isHover = false,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: isPressed 
          ? backgroundSecondary 
          : isHover 
              ? backgroundTertiary 
              : backgroundLayer,
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(
        color: isPressed ? borderStrong : borderPrimary,
        width: 1,
      ),
      boxShadow: [
        if (!isPressed)
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: isHover ? 8 : 4,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }
  
  /// 揭示边框效果 (Reveal Border)
  static BoxDecoration revealBorder({
    Color? accentColor,
    bool isHover = false,
  }) {
    return BoxDecoration(
      color: backgroundLayer,
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(
        color: isHover 
            ? (accentColor ?? accentPrimary).withOpacity(0.5)
            : borderPrimary,
        width: isHover ? 2 : 1,
      ),
    );
  }

  // ========== 按钮样式 ==========
  
  static ButtonStyle accentButton = ElevatedButton.styleFrom(
    backgroundColor: accentPrimary,
    foregroundColor: textInverse,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    ),
    elevation: 0,
  );
  
  static ButtonStyle standardButton = ElevatedButton.styleFrom(
    backgroundColor: backgroundSecondary,
    foregroundColor: textPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      side: BorderSide(color: borderPrimary),
    ),
    elevation: 0,
  );
  
  static ButtonStyle subtleButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: textPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
    ),
    elevation: 0,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return backgroundTertiary;
      }
      return null;
    }),
  );

  // ========== 文字样式 (Segoe UI 风格) ==========
  
  static TextStyle textDisplay = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,  // SemiBold
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static TextStyle textHeading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.3,
  );
  
  static TextStyle textHeading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  
  static TextStyle textHeading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.5,
  );
  
  static TextStyle textBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );
  
  static TextStyle textBodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );
  
  static TextStyle textCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  
  static TextStyle textLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );

  // ========== 节点颜色 (保留功能) ==========
  
  static final Map<String, Color> nodeColors = {
    'message': accentPrimary,
    'milestone': const Color(0xFF744DA9),
    'branch': const Color(0xFFFFA500),
    'merge': success,
    'aiSummary': const Color(0xFFEC4899),
  };
  
  static final Map<String, Color> leafColors = {
    'summary': accentPrimary,
    'actionItems': const Color(0xFFFFA500),
    'decision': const Color(0xFF744DA9),
    'riskAlert': error,
    'insight': success,
    'reference': const Color(0xFF6B7280),
  };

  // ========== 主题数据 ==========
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundBase,
      colorScheme: ColorScheme.light(
        primary: accentPrimary,
        secondary: accentSecondary,
        surface: backgroundLayer,
        background: backgroundBase,
        error: error,
        onPrimary: textInverse,
        onSecondary: textInverse,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textInverse,
      ),
      textTheme: TextTheme(
        displayLarge: textDisplay,
        headlineLarge: textHeading1,
        headlineMedium: textHeading2,
        headlineSmall: textHeading3,
        bodyLarge: textBodyLarge,
        bodyMedium: textBody,
        labelMedium: textLabel,
        bodySmall: textCaption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: accentButton,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLayer,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textHeading3,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: backgroundLayer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderPrimary,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: borderPrimary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: borderPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: accentPrimary, width: 2),
        ),
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      colorScheme: ColorScheme.dark(
        primary: accentPrimary,
        secondary: accentSecondary,
        surface: Color(0xFF2D2D2D),
        error: error,
        onPrimary: textInverse,
        onSecondary: textInverse,
        onSurface: textPrimaryLight,
        onError: textInverse,
      ),
      textTheme: TextTheme(
        displayLarge: textDisplay,
        headlineLarge: textHeading1,
        headlineMedium: textHeading2,
        headlineSmall: textHeading3,
        bodyLarge: textBodyLarge,
        bodyMedium: textBody,
        labelMedium: textLabel,
        bodySmall: textCaption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: accentButton,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF2D2D2D),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textHeading3,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2D2D2D),  // 保持 const 因为是硬编码颜色
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderPrimary,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3D3D3D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: borderPrimary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: borderPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: accentPrimary, width: 2),
        ),
      ),
    );
  }
}

/// Fluent Design 卡片 Widget
class FluentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isSelected;

  const FluentCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.accentLight 
                : AppTheme.backgroundLayer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.accentPrimary 
                  : AppTheme.borderPrimary,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Fluent Design 按钮 Widget
class FluentButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final FluentButtonStyle style;

  const FluentButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style = FluentButtonStyle.accent,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    
    switch (style) {
      case FluentButtonStyle.accent:
        bgColor = AppTheme.accentPrimary;
        fgColor = AppTheme.textInverse;
        break;
      case FluentButtonStyle.standard:
        bgColor = AppTheme.backgroundSecondary;
        fgColor = AppTheme.textPrimary;
        break;
      case FluentButtonStyle.subtle:
        bgColor = Colors.transparent;
        fgColor = AppTheme.textPrimary;
        break;
    }

    return MouseRegion(
      cursor: onPressed != null 
          ? SystemMouseCursors.click 
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: style == FluentButtonStyle.standard
                ? Border.all(color: AppTheme.borderPrimary)
                : null,
          ),
          child: DefaultTextStyle(
            style: AppTheme.textBody.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

enum FluentButtonStyle {
  accent,    // 强调按钮
  standard,  // 标准按钮
  subtle,    // 微妙按钮
}

/// 导航视图 (NavigationView) - WinUI 3 风格
class NavigationView extends StatelessWidget {
  final Widget? sidebar;
  final Widget content;
  final Widget? appBar;

  const NavigationView({
    super.key,
    this.sidebar,
    required this.content,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: appBar != null 
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: appBar!,
            )
          : null,
      body: Row(
        children: [
          if (sidebar != null)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: AppTheme.backgroundLayer,
                border: Border(
                  right: BorderSide(color: AppTheme.borderPrimary),
                ),
              ),
              child: sidebar,
            ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
