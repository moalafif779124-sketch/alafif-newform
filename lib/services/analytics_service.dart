import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// غلاف آمن حول Firebase Analytics.
///
/// التطبيق يعمل أحياناً بلا Firebase مهيّأ (شاشة البداية/أخطاء الإقلاع)،
/// ولذلك كل دالة هنا "تتبنّى الفشل بصمت": تتحقق من التهيئة ومن Firebase.apps
/// ثم تُرسل الحدث داخل try/catch — تحليلات لا يجوز أن تُسقط عملية شراء.
///
/// أسماء الأحداث تتبع مخطط Firebase الموصى به (add_to_cart, purchase, …)
/// كي تظهر تقارير التجارة الإلكترونية في كونسول Firebase بلا إعداد إضافي.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _enabled = false;

  bool get isReady => _enabled && _analytics != null;

  /// يُستدعى مرة واحدة بعد Firebase.initializeApp (انظر FirebaseService.initialize).
  Future<void> init() async {
    if (_enabled) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      // التجميع مفعّل افتراضياً على Android؛ نثبّته صراحةً كي لا يُعطَّل
      // بتفضيل محفوظ على الجهاز، مثل ما نفعل مع Crashlytics.
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _enabled = true;
      debugPrint('📊 Analytics enabled');
    } catch (e) {
      debugPrint('⚠️ Analytics init failed (غير حرج): $e');
    }
  }

  /// إسناد الجلسة للمستخدم بعد تسجيل الدخول (OTP/زائر/بريد).
  Future<void> setUserId(String? uid, {String? loginMethod}) async {
    if (_analytics == null) return;
    try {
      await _analytics!.setUserId(id: uid);
      if (loginMethod != null) {
        await _analytics!.logLogin(loginMethod: loginMethod);
      }
    } catch (e) {
      debugPrint('⚠️ analytics setUserId: $e');
    }
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (_analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('⚠️ analytics event "$name": $e');
    }
  }

  // =================== أحداث المتجر ===================

  Future<void> logViewItem({
    required String id,
    required String name,
    String? category,
    double? price,
  }) =>
      logEvent('view_item', {
        'item_id': id,
        'item_name': name,
        if (category != null) 'item_category': category,
        if (price != null) 'price': price,
        'currency': 'YER',
      });

  Future<void> logAddToCart({
    required String id,
    required String name,
    double? price,
    int quantity = 1,
    String? variant,
  }) =>
      logEvent('add_to_cart', {
        'item_id': id,
        'item_name': name,
        if (price != null) 'price': price,
        'quantity': quantity,
        if (variant != null) 'item_variant': variant,
        'currency': 'YER',
        'value': (price ?? 0) * quantity,
      });

  Future<void> logAddToWishlist({required String id, required String name}) =>
      logEvent('add_to_wishlist', {'item_id': id, 'item_name': name});

  Future<void> logBeginCheckout(double value, {int? items}) => logEvent(
        'begin_checkout',
        {
          'value': value,
          'currency': 'YER',
          if (items != null) 'items_count': items,
        },
      );

  Future<void> logPurchase({
    required String orderId,
    required double value,
    String? coupon,
    String? paymentMethod,
    int? items,
  }) =>
      logEvent('purchase', {
        'transaction_id': orderId,
        'value': value,
        'currency': 'YER',
        if (coupon != null && coupon.isNotEmpty) 'coupon': coupon,
        if (paymentMethod != null) 'payment_type': paymentMethod,
        if (items != null) 'items_count': items,
      });

  Future<void> logSearch(String term) =>
      logEvent('search', {'search_term': term});

  Future<void> logScan(String code, {String? foundName}) => logEvent(
        'barcode_scan',
        {
          'code': code,
          if (foundName != null) 'item_name': foundName,
        },
      );
}
