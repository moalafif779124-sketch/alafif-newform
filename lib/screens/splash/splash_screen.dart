import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../auth/login_screen.dart';
import '../shell_screen.dart';

/// شاشة البداية الترحيبية
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // تهيئة المزودات
    _initializeProviders();

    // بدء عداد 2.5 ثانية ثم التنقل
    _timer = Timer(const Duration(milliseconds: 2500), _navigate);
  }

  Future<void> _initializeProviders() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final productProvider = context.read<ProductProvider>();

      await Future.wait([
        authProvider.initialize(),
        productProvider.initialize(),
      ]);
    } catch (e) {
      debugPrint('SplashScreen initialization error: $e');
    }
  }

  void _navigate() {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    if (authProvider.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 120),
              const Text(
                'ALAFIF NEWFORM',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'العفيف نيوفورم',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.accentLight,
                ),
              ),
              const SizedBox(height: 60),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
