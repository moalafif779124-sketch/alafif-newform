import 'package:flutter/material.dart';

/// لوحتا ألوان التطبيق: الفاتحة والداكنة.
///
/// القيم هنا ثابتة (`static const`) حتى تُستخدم داخل `ThemeData` وفي سياقات
/// `const` بلا مشاكل. للاستخدام اليومي داخل الشاشات استعمل [AppColors]
/// (getters تتغيّر تلقائياً حسب الوضع الحالي)، لا هذه الأصناف مباشرة.
class LightPalette {
  LightPalette._();

  static const Color primary = Color(0xFF0D1B3E);
  static const Color primaryLight = Color(0xFF1A2D5E);
  static const Color primaryDark = Color(0xFF070E24);

  static const Color accent = Color(0xFFC0C0C0);
  static const Color accentLight = Color(0xFFE8E8E8);
  static const Color accentDark = Color(0xFF8A8A8A);

  static const Color background = Color(0xFFEAEDED);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF1A1A2E);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF0F0F0);

  static const Color amazonDark = Color(0xFF131921);
  static const Color amazonNavy = Color(0xFF232F3E);
  static const Color amazonTeal = Color(0xFF37475A);
  static const Color amazonOrange = Color(0xFFFF9900);
  static const Color amazonYellow = Color(0xFFFEBD69);
  static const Color amazonBlue = Color(0xFF146EB4);
  static const Color amazonBg = Color(0xFFEAEDED);
}

/// اللوحة الداكنة المستوحاة من "الفخامة الليلية": خلفيات كحلية عميقة،
/// نصوص فاتحة، وذهبي العلامة كلون بارز بديل للكحلي في وضع النصوص والأيقونات.
class DarkPalette {
  DarkPalette._();

  /// ذهبي العلامة — يُستخدم كنص/أيقونة وروابط داخل الوضع الداكن.
  static const Color primary = Color(0xFFE0B75A);
  static const Color primaryLight = Color(0xFFEFCB7A);
  static const Color primaryDark = Color(0xFFB08A2E);

  static const Color accent = Color(0xFFC9C9D6);
  static const Color accentLight = Color(0xFF2A2A4A);
  static const Color accentDark = Color(0xFF8A8A9E);

  static const Color background = Color(0xFF12122A);
  static const Color surface = Color(0xFF1A1A36);
  static const Color cardBackground = Color(0xFF1A1A36);

  static const Color textPrimary = Color(0xFFEDEDF7);
  static const Color textSecondary = Color(0xFFA9A9C0);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF0A0A1A);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static const Color border = Color(0xFF2E2E52);
  static const Color divider = Color(0xFF262647);

  static const Color amazonDark = Color(0xFF131921);
  static const Color amazonNavy = Color(0xFF232F3E);
  static const Color amazonTeal = Color(0xFF37475A);
  static const Color amazonOrange = Color(0xFFFF9900);
  static const Color amazonYellow = Color(0xFFFEBD69);
  static const Color amazonBlue = Color(0xFF4A9EE0);
  static const Color amazonBg = Color(0xFF0A0A1A);
}

/// الألوان الرئيسية للعلامة التجارية "العفيف نيوفورم".
///
/// - **الألوان المتغيّرة** (`primary`, `textPrimary`, `background`, `border`...)
///   تُقرأ حسب [brightness] الذي يضبطه `MaterialApp.builder` في `main.dart`
///   عند كل تغيير للثيم، لذا تكتب الشاشات نفس الاستدعاء بلا أي شرط.
/// - **الألوان الثابتة** (هوية العلامة الكحلية/البرتقالية + ألوان الحالة)
///   تبقى كما هي في الوضعين، وتبقى `const` لتعمل داخل سياقات `const`.
///
/// تحذير: لأن المتغيّرة getters، لا يمكن استخدامها داخل تعبير `const`؛
/// احذف `const` من التركيب الذي يحتوي عليها.
class AppColors {
  AppColors._();

  /// وضع العرض الحالي — يضبطه `main.dart` قبل بناء شجرة الواجهات.
  static Brightness brightness = Brightness.light;

  static bool get isDark => brightness == Brightness.dark;

  // =========== ألوان ثابتة (هوية العلامة) ===========
  /// الخلفية الكحلية الداكنة — تُستخدم خلفيةً في الوضعين (مع نص أبيض).
  static const Color primarySurface = Color(0xFF0D1B3E);
  static const Color primaryGradientStart = Color(0xFF232F3E);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color discount = Color(0xFFEF4444);
  static const Color favorite = Color(0xFFEF4444);
  static const Color rating = Color(0xFFF59E0B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // =========== باقة أمازون (ثابتة) ===========
  static const Color amazonDark = Color(0xFF131921);
  static const Color amazonNavy = Color(0xFF232F3E);
  static const Color amazonTeal = Color(0xFF37475A);
  static const Color amazonOrange = Color(0xFFFF9900);
  static const Color amazonYellow = Color(0xFFFEBD69);
  static const Color amazonBg = Color(0xFFEAEDED);

  static Color get amazonBlue =>
      isDark ? DarkPalette.amazonBlue : LightPalette.amazonBlue;

  // =========== ألوان متغيّرة حسب الوضع ===========
  static Color get primary =>
      isDark ? DarkPalette.primary : LightPalette.primary;
  /// الكحلي الفاتح — يُستخدم خلفيةً فقط (ثابت في الوضعين مع نص فاتح).
  static const Color primaryLight = Color(0xFF1A2D5E);

  /// الكحلي الأعمق — خلفية شاشات الدخول/التحقق (ثابت في الوضعين).
  static const Color primaryDark = Color(0xFF070E24);

  static Color get accent => isDark ? DarkPalette.accent : LightPalette.accent;
  static Color get accentLight =>
      isDark ? DarkPalette.accentLight : LightPalette.accentLight;
  static Color get accentDark =>
      isDark ? DarkPalette.accentDark : LightPalette.accentDark;

  static Color get background =>
      isDark ? DarkPalette.background : LightPalette.background;
  static Color get surface =>
      isDark ? DarkPalette.surface : LightPalette.surface;
  static Color get cardBackground =>
      isDark ? DarkPalette.cardBackground : LightPalette.cardBackground;

  static Color get textPrimary =>
      isDark ? DarkPalette.textPrimary : LightPalette.textPrimary;
  static Color get textSecondary =>
      isDark ? DarkPalette.textSecondary : LightPalette.textSecondary;
  static Color get textOnAccent =>
      isDark ? DarkPalette.textOnAccent : LightPalette.textOnAccent;

  static Color get border => isDark ? DarkPalette.border : LightPalette.border;
  static Color get divider =>
      isDark ? DarkPalette.divider : LightPalette.divider;

  // =========== خلفيات متدرجة ===========
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amazonNavy, amazonTeal],
  );

  static const LinearGradient amazonYellowGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [amazonYellow, amazonOrange],
  );

  static const LinearGradient amazonOrangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amazonOrange, Color(0xFFE8890C)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC0C0C0), Color(0xFFE8E8E8)],
  );

  // =========== الظلال ===========
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
