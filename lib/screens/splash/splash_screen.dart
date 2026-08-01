import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../shell_screen.dart';

/// شاشة البداية مع أنيميشن
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _subtitleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _loaderFade;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // ===== أنيميشن متدرج =====
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3, curve: Curves.easeIn)),
    );
    _subtitleSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.55, curve: Curves.easeOutCubic)),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.5, curve: Curves.easeIn)),
    );
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 0.7, curve: Curves.easeIn)),
    );

    _controller.forward();

    // تهيئة المزودات
    _initializeProviders();

    // التنقل بعد 3 ثوان
    _navTimer = Timer(const Duration(milliseconds: 3000), _navigate);
  }

  Future<void> _initializeProviders() async {
    try {
      final authProvider = context.read<AuthProvider>();

      // ===== تشغيل أساسي فقط: المصادقة والإشعارات =====
      // (لا يُحمّل ProductProvider هنا — يُشغَّل بعد عرض أول إطار)
      await Future.wait([
        authProvider.initialize(),
        NotificationService().initialize(),
      ]);

      // طلب صلاحية الإشعارات بعد التهيئة
      NotificationService().requestPermission();

      // ربط FCM بالمستخدم (تسجيل token)
      if (authProvider.isLoggedIn &&
          (authProvider.userId != null && authProvider.userId!.isNotEmpty)) {
        await NotificationService().setUserId(authProvider.userId);
        context.read<CartProvider>().setUserId(authProvider.userId);
      }

      // إعداد معالجات الرسائل الواردة من FCM
      NotificationService().setupMessageHandlers();
    } catch (e) {
      debugPrint('SplashScreen initialization error: $e');
    }
  }

  void _navigate() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            authProvider.isLoggedIn ? const MainShell() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ===== الشعار متحرك =====
                  Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'AN',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ===== اسم التطبيق متحرك =====
                  Opacity(
                    opacity: _subtitleFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _subtitleSlide.value),
                      child: Column(
                        children: [
                          Text(
                            'ALAFIF NEWFORM',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  color: AppColors.accent.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'العفيف نيوفورم',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.accentLight.withValues(alpha: 0.8),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // ===== مؤشر التحميل متحرك =====
                  Opacity(
                    opacity: _loaderFade.value,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accent.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'جاري التحميل...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.accentLight.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
