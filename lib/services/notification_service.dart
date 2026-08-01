import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_service.dart';
import '../models/order.dart';
import '../widgets/product_detail_route.dart';
import '../screens/profile/order_tracking_screen.dart';

/// خدمة الإشعارات - تدعم FCM (Firebase Cloud Messaging)
/// مع إشعارات محلية عبر flutter_local_notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;
  String? _fcmToken;
  String? _userId;

  /// مفتاح التنقل العام — يُستخدم للانتقال إلى الشاشات من الإشعارات
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool get isInitialized => _initialized;
  String? get fcmToken => _fcmToken;

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
    debugPrint('🔔 NotificationService initialized');
  }

  /// ربط FCM بمستخدم معين (يُستدعى بعد تسجيل الدخول)
  Future<void> setUserId(String? userId) async {
    _userId = userId;
    if (userId != null && userId.isNotEmpty) {
      await _registerFcmToken();
    }
  }

  /// طلب صلاحية الإشعارات من المستخدم
  Future<bool> requestPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      debugPrint('🔔 Notification permission: $granted');
      return granted;
    } catch (e) {
      debugPrint('⚠️ Failed to request notification permission: $e');
      return false;
    }
  }

  /// تسجيل FCM token وحفظه في Firestore
  Future<void> _registerFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('🔔 FCM Token: $_fcmToken');

      if (_fcmToken != null && _userId != null) {
        await FirebaseService().saveFcmToken(_userId!, _fcmToken!);
      }

      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔔 FCM Token refreshed: $newToken');
        if (_userId != null) {
          FirebaseService().saveFcmToken(_userId!, newToken);
        }
      });
    } catch (e) {
      debugPrint('⚠️ Failed to register FCM token: $e');
    }
  }

  /// إعداد معالجات الرسائل الواردة
  void setupMessageHandlers() {
    // 1. فتح التطبيق من إشعار (التطبيق مقتول)
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('🔔 App opened from terminated state: ${message.messageId}');
        _handleNotificationTap(message.data);
      }
    });

    // 2. النقر على إشعار والتطبيق في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 App opened from background: ${message.messageId}');
      _handleNotificationTap(message.data);
    });

    // 3. استلام إشعار والتطبيق في المقدمة
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Message received in foreground: ${message.messageId}');
      _showLocalNotification(message);
    });
  }

  /// عرض إشعار محلي (يُستخدم عندما يكون التطبيق في المقدمة)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidChannel = AndroidNotificationDetails(
      'order_updates',
      'تحديثات الطلبات',
      channelDescription: 'إشعارات تحديث حالة الطلبات',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const platformChannel = NotificationDetails(android: androidChannel);

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? '',
      notification.body ?? '',
      platformChannel,
      payload: jsonEncode(message.data),
    );
  }

  /// معالجة النقر على الإشعار المحلي
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationTap(data);
      } catch (e) {
        debugPrint('⚠️ Failed to parse notification payload: $e');
      }
    }
  }

  /// توجيه المستخدم بعد النقر على الإشعار
  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    // إشعار تخفيض خاطف — افتح صفحة المنتج مباشرة
    if (type == 'flash_sale') {
      final productId = data['productId'] as String?;
      if (productId != null && productId.isNotEmpty) {
        _navigateToProduct(productId);
      }
      return;
    }

    final orderId = data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return;
    _navigateToOrder(orderId);
  }

  /// التنقل إلى صفحة تفاصيل المنتج
  void _navigateToProduct(String productId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const ProductDetailRoute(productId: productId),
      ),
    );
  }

  /// التنقل إلى شاشة تتبع الطلب
  void _navigateToOrder(String orderId) async {
    // جلب بيانات الطلب
    final orderData = await FirebaseService().getOrderById(orderId);
    if (orderData == null) {
      debugPrint('⚠️ Order not found: $orderId');
      return;
    }
    final order = Order.fromMap(orderData);

    // التنقل إلى شاشة التتبع
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(order: order),
      ),
    );
  }

  /// إرسال إشعار للطلب (محاكاة - الإرسال الفعلي عبر Cloud Function)
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

    const androidChannel = AndroidNotificationDetails(
      'order_updates',
      'تحديثات الطلبات',
      channelDescription: 'إشعارات تحديث حالة الطلبات',
      importance: Importance.high,
      priority: Priority.high,
    );
    const platformChannel = NotificationDetails(android: androidChannel);
    await _localNotifications.show(
      orderNumber.hashCode,
      title,
      body,
      platformChannel,
    );
  }

  /// معالجة رسالة واردة من FCM (للتطبيقات القديمة)
  void handleMessage(Map<String, dynamic> message) {
    debugPrint('🔔 Received message: ${jsonEncode(message)}');
    final notification = message['notification'] as Map<String, dynamic>?;
    if (notification != null) {
      final title = notification['title'] ?? '';
      final body = notification['body'] ?? '';
      debugPrint('🔔 Local notification: $title - $body');
    }
  }
}
