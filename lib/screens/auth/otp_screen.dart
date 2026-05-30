import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../providers/auth_provider.dart';

/// شاشة إدخال رمز التحقق (OTP) - عبر واتساب
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _needsName = false;
  bool _otpVisible = false;

  @override
  void dispose() {
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // عرض رمز OTP للمستخدم عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.otpCode != null && mounted) {
        _showOtpSnackbar(auth.otpCode!);
      }
    });
  }

  void _showOtpSnackbar(String otp) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('رمز التحقق: $otp'),
        backgroundColor: const Color(0xFF25D366),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'نسخ',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: otp));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم نسخ الرمز'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  void _verifyOtp() {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    if (_needsName) {
      if (_nameController.text.trim().isEmpty) {
        return;
      }
      auth.confirmOtp(
        otp: _otpController.text.trim(),
        fullName: _nameController.text.trim(),
      );
    } else {
      // نحاول تسجيل الدخول بالـ OTP
      auth.confirmOtp(otp: _otpController.text.trim()).then((success) {
        if (!success && mounted) {
          // إذا فشل لأن المستخدم جديد ويحتاج اسم، نظهر حقل الاسم
          final error = auth.error;
          if (error != null && error.contains('الاسم')) {
            setState(() => _needsName = true);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.read<AuthProvider>().cancelOtp();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: AppColors.accentLight,
                ),
                const SizedBox(height: 24),
                const Text(
                  'رمز التحقق',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل رمز التحقق المرسل عبر واتساب',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // زر عرض الرمز
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.otpCode == null) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () {
                        setState(() => _otpVisible = !_otpVisible);
                        if (_otpVisible && auth.otpCode != null) {
                          _showOtpSnackbar(auth.otpCode!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _otpVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 16,
                              color: AppColors.accentLight.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'عرض رمز التحقق',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.accentLight.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // حقل رمز التحقق
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 28,
                      letterSpacing: 12,
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
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return 'أدخل رمز التحقق كاملاً';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // حقل الاسم (للمستخدم الجديد)
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (!_needsName && auth.error != null && auth.error!.contains('الاسم')) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => _needsName = true);
                      });
                    }
                    return _needsName
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'مستخدم جديد! أدخل اسمك الكامل:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'الاسم الثلاثي',
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
                                    Icons.person,
                                    color: AppColors.accentLight,
                                  ),
                                ),
                                validator: (v) {
                                  if (_needsName && (v == null || v.isEmpty)) {
                                    return 'الاسم مطلوب';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                            ],
                          )
                        : const SizedBox.shrink();
                  },
                ),

                // زر التأكيد
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _verifyOtp,
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
                                'تأكيد',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  },
                ),

                // زر إعادة الإرسال
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isLoading) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: () async {
                        await auth.resendOtp();
                        if (mounted && auth.otpCode != null) {
                          _showOtpSnackbar(auth.otpCode!);
                        }
                      },
                      child: const Text(
                        'إعادة إرسال الرمز',
                        style: TextStyle(
                          color: AppColors.accentLight,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

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
        ),
      ),
    );
  }
}
