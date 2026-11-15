import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'config/colors.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/order_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/review_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/points_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/in_store_provider.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'screens/splash/splash_screen.dart';

/// معالج الرسائل في الخلفية (التطبيق مغلق أو في الخلفية)
///
/// مطلوب في القمة (top-level) مع @pragma('vm:entry-point') — بدونه تُهمَل
/// رسائل FCM التي تحمل data فقط أثناء وجود التطبيق في الخلفية/مغلقاً.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Background FCM message: ${message.messageId} '
      'type=${message.data['type']}');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ===== تقارير الانهيار =====
  // Firebase لا يكون مهيّأً بعد في هذه اللحظة (يُهيَّأ في شاشة البداية)، لذلك
  // نتحقق من Firebase.apps كي لا ينهار المعالج نفسه قبل التهيئة.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    debugPrint('⛔ Uncaught: $error');
    return true;
  };
  // تسجيل معالج الخلفية قبل أي تهيئة أخرى
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // تهيئة الكاش المحلي قبل الإقلاع — يضمن عرض فوري
  CacheService.instance.init();
  runApp(const ALAFIFApp());
}

class ALAFIFApp extends StatelessWidget {
  const ALAFIFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => PointsProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => InStoreProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'العفيف نيوفورم',
            debugShowCheckedModeBanner: false,

            // =========== مفتاح التنقل من الإشعارات ===========
            navigatorKey: NotificationService.navigatorKey,

            // =========== الثيم (فاتح/داكن) ===========
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,

            // =========== RTL ===========
            locale: const Locale('ar', 'SA'),
            supportedLocales: const [
              Locale('ar', 'SA'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            localeResolutionCallback: (locale, supportedLocales) {
              for (final supported in supportedLocales) {
                if (supported.languageCode == locale?.languageCode) {
                  return supported;
                }
              }
              return supportedLocales.first;
            },

            // =========== مزامنة لوحة الألوان مع الثيم الحالي ===========
            // يضبط وضع العرض قبل بناء شجرة الواجهات، فتُقرأ ألوان AppColors
            // (النصوص/الخلفيات/الحدود) الصحيحة في كل صفحة بلا أي شرط محلي.
            builder: (context, child) {
              AppColors.brightness = Theme.of(context).brightness;
              return child ?? const SizedBox.shrink();
            },

            // =========== البداية ===========
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
