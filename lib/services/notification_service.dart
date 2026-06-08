import 'dart:convert';
import 'package:flutter/foundation.dart';

/// خدمة الإشعارات - تدعم FCM (Firebase Cloud Messaging)
/// وإشعارات الطلبات المحلية
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('🔔 NotificationService initialized');
  }

  /// طلب صلاحية الإشعارات
  Future<bool> requestPermission() async {
    // Android لا يحتاج صلاحية منفصلة للإشعارات
    debugPrint('🔔 Notification permission requested');
    return true;
  }

  /// إرسال إشعار محلي (للاختبار/التنبيهات الفورية)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('🔔 Local notification: $title - $body');
    // في الإصدار الحالي، نسجل الإشعار في السجل فقط.
    // يمكن تفعيل flutter_local_notifications لاحقاً
  }

  /// إرسال إشعار للطلب (محاكاة - سيتم تفعيل FCM لاحقاً)
  Future<void> sendOrderNotification({
    required String orderNumber,
    required String status,
  }) async {
    final titles = {
      'confirmed': 'تم تأكيد الطلب ✓',
      'processing': 'طلبك قيد التجهيز',
      'shipped': 'تم شحن طلبك 🚚',
      'delivered': 'تم توصيل طلبك ✅',
      'cancelled': 'تم إلغاء الطلب',
    };

    final bodies = {
      'confirmed': 'تم تأكيد الطلب رقم $orderNumber وسيتم تجهيزه قريباً',
      'processing': 'طلبك رقم $orderNumber قيد التجهيز الآن',
      'shipped': 'طلبك رقم $orderNumber في طريقه إليك',
      'delivered': 'تم توصيل الطلب رقم $orderNumber بنجاح',
      'cancelled': 'تم إلغاء الطلب رقم $orderNumber',
    };

    final title = titles[status] ?? 'تحديث الطلب';
    final body = bodies[status] ?? 'تم تحديث حالة الطلب رقم $orderNumber';

    await showLocalNotification(title: title, body: body);
  }

  /// معالجة رسالة واردة من FCM
  void handleMessage(Map<String, dynamic> message) {
    debugPrint('🔔 Received message: ${jsonEncode(message)}');

    final notification = message['notification'] as Map<String, dynamic>?;
    if (notification != null) {
      final title = notification['title'] ?? '';
      final body = notification['body'] ?? '';
      showLocalNotification(title: title, body: body);
    }
  }
}
