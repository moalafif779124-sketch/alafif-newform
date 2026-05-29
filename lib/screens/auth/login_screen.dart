import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../providers/auth_provider.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

/// شاشة تسجيل الدخول - بخيارين: واتساب (جوال) أو بريد إلكتروني
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Phone login
  final _phoneController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();

  // Email login
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    // تنسيق الرقم
    String formattedPhone = phone;
    if (!phone.startsWith('+')) {
      formattedPhone = '+967$phone'; // افتراضياً اليمن
    }

    final authProvider = context.read<AuthProvider>();
    authProvider.sendOtp(formattedPhone).then((success) {
      if (success && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const OtpScreen(),
          ),
        );
      }
    });
  }

  void _loginWithEmail() {
    if (!_emailFormKey.currentState!.validate()) return;

    context.read<AuthProvider>().loginWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // الشعار
            const SizedBox(height: 60),
            const Icon(
              Icons.store,
              size: 80,
              color: AppColors.accentLight,
            ),
            const SizedBox(height: 16),
            const Text(
              'العفيف نيوفورم',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الأناقة الرجالية الفاخرة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 40),

            // التبويبات
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.whatsapp, size: 20),
                        SizedBox(width: 8),
                        Text('واتساب'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email, size: 20),
                        SizedBox(width: 8),
                        Text('بريد إلكتروني'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // المحتوى
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPhoneTab(),
                  _buildEmailTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _phoneFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'تسجيل الدخول برقم الجوال',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم إرسال رمز تحقق إلى رقم جوالك عبر واتساب أو رسالة نصية',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // رقم الجوال
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                prefixText: '+967 ',
                prefixStyle: const TextStyle(color: Colors.white70),
                hintText: '777123456',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.accentLight,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.phone_android,
                  color: AppColors.accentLight,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال رقم الجوال';
                if (v.length < 7) return 'رقم الجوال غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // زر الإرسال
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // واتساب
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.whatsapp, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'إرسال رمز التحقق',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),

            // عرض الخطأ
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'تسجيل الدخول بالبريد الإلكتروني',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // البريد الإلكتروني
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'example@email.com',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.accentLight,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.email,
                  color: AppColors.accentLight,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال البريد الإلكتروني';
                if (!v.contains('@')) return 'البريد الإلكتروني غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // كلمة المرور
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'كلمة المرور',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.accentLight,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.lock,
                  color: AppColors.accentLight,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'الرجاء إدخال كلمة المرور';
                if (v.length < 6) return 'كلمة المرور قصيرة جداً';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // زر تسجيل الدخول
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentLight,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // رابط التسجيل
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ),
                  );
                },
                child: Text(
                  'ليس لديك حساب؟ أنشئ حساب جديد',
                  style: TextStyle(
                    color: AppColors.accentLight.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),

            // عرض الخطأ
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
