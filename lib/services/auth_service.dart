import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app;
import 'firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// جلسة OTP مؤقتة
class OtpSession {
  final String code;
  final DateTime expiresAt;
  final String phone;

  OtpSession({
    required this.code,
    required this.phone,
    DateTime? expiresAt,
  }) : expiresAt = expiresAt ?? DateTime.now().add(const Duration(minutes: 5));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool verify(String input) => code == input && !isExpired;
}

/// خدمة المصادقة - OTP عبر واتساب + البريد الإلكتروني
class AuthService {
  final FirebaseService _firebaseService = FirebaseService();
  
  // تخزين OTP محلياً (في الذاكرة للمستخدم الحالي)
  OtpSession? _currentOtpSession;
  String? _pendingPhone;

  String? get pendingPhone => _pendingPhone;

  // =================== OTP عبر واتساب ===================

  /// توليد رمز OTP عشوائي 6 أرقام
  String _generateOtpCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// رابط واتساب للرسالة المباشرة
  String _buildWhatsAppUrl(String phone, String otpCode) {
    // إزالة + من البداية
    final cleanPhone = phone.replaceAll('+', '');
    final message = Uri.encodeComponent(
      'رمز التحقق الخاص بك في العفيف نيوفورم هو: $otpCode\n'
      'يرجى عدم مشاركة هذا الرمز مع أي شخص.'
    );
    return 'https://api.whatsapp.com/send?phone=$cleanPhone&text=$message';
  }

  /// رابط واتساب لفتح محادثة مع المتجر
  String _buildStoreWhatsAppUrl(String userPhone, String otpCode) {
    final storePhone = '967717500431'; // رقم المتجر - غيّره حسب الحاجة
    final message = Uri.encodeComponent(
      'مستخدم جديد - الرقم: $userPhone\n'
      'رمز التحقق: $otpCode'
    );
    return 'https://api.whatsapp.com/send?phone=$storePhone&text=$message';
  }

  /// إنشاء OTP وتحضير رابط واتساب
  /// يرجع (otpCode, whatsappUrl) أو يرمي خطأ
  Future<Map<String, String>> sendOtp(String phone) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    final otpCode = _generateOtpCode();
    _currentOtpSession = OtpSession(
      code: otpCode,
      phone: phone,
    );
    _pendingPhone = phone;

    debugPrint('🔐 OTP generated for $phone: $otpCode');

    // بناء رابط واتساب - يرسل الرمز لرقم المستخدم نفسه
    final whatsappUrl = _buildWhatsAppUrl(phone, otpCode);
    
    return {
      'otp': otpCode,
      'phone': phone,
      'whatsappUrl': whatsappUrl,
    };
  }

  /// إعادة إرسال OTP (يولّد رمز جديد)
  Future<Map<String, String>> resendOtp() async {
    if (_pendingPhone == null) {
      throw Exception('الرجاء إدخال رقم الجوال أولاً');
    }
    return sendOtp(_pendingPhone!);
  }

  /// التحقق من رمز OTP محلياً
  bool verifyOtp(String inputOtp) {
    if (_currentOtpSession == null) {
      debugPrint('⚠️ No OTP session found');
      return false;
    }

    if (_currentOtpSession!.isExpired) {
      debugPrint('⚠️ OTP expired');
      _currentOtpSession = null;
      return false;
    }

    final isValid = _currentOtpSession!.verify(inputOtp);
    if (!isValid) {
      debugPrint('⚠️ Invalid OTP: entered=$inputOtp, expected=${_currentOtpSession!.code}');
    }
    return isValid;
  }

  /// إنشاء حساب جديد أو تحميل حساب موجود بعد التحقق من OTP
  Future<app.AppUser> createOrLoginUser({
    required String otp,
    String? fullName,
  }) async {
    if (!verifyOtp(otp)) {
      if (_currentOtpSession?.isExpired ?? false) {
        throw Exception('انتهت صلاحية رمز التحقق، أرسل رمز جديد');
      }
      throw Exception('رمز التحقق غير صحيح');
    }

    final phone = _pendingPhone;
    if (phone == null) {
      throw Exception('الرجاء إرسال رمز التحقق أولاً');
    }

    try {
      // تسجيل دخول مجهول عبر Firebase Auth (للحصول على UID)
      UserCredential? anonCredential;
      try {
        anonCredential = await _firebaseService.auth.signInAnonymously();
      } catch (e) {
        debugPrint('⚠️ Anonymous auth failed: $e');
        // لو فشل anonymous auth، نستخدم رقم الجوال كـ ID
      }

      final uid = anonCredential?.user?.uid ?? 'phone_${phone.replaceAll('+', '')}';
      
      // البحث عن مستخدم موجود بنفس رقم الجوال
      final existingUsers = await _firebaseService.firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        // مستخدم موجود ← تسجيل دخول
        final userData = existingUsers.docs.first.data();
        userData['id'] = existingUsers.docs.first.id;
        _clearOtpSession();
        return app.AppUser.fromMap(userData);
      }

      // مستخدم جديد
      if (fullName == null || fullName.trim().isEmpty) {
        throw Exception('مطلوب الاسم الكامل للمستخدم الجديد');
      }

      // تأكد من عدم وجود مستخدم بنفس UID
      final existingByUid = await _firebaseService.getUser(uid);
      if (existingByUid != null) {
        _clearOtpSession();
        return app.AppUser.fromMap(existingByUid);
      }

      final user = app.AppUser(
        id: uid,
        fullName: fullName.trim(),
        phone: phone,
        createdAt: DateTime.now(),
      );

      await _firebaseService.saveUser(user.toMap());
      _clearOtpSession();
      return user;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('فشل إنشاء الحساب: $e');
    }
  }

  void _clearOtpSession() {
    _currentOtpSession = null;
    _pendingPhone = null;
  }

  void cancelOtp() {
    _clearOtpSession();
  }

  // =================== التسجيل بالبريد الإلكتروني ===================

  Future<app.AppUser> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    UserCredential userCredential;
    try {
      userCredential = await _firebaseService.auth
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
    } catch (e) {
      throw Exception('فشل إنشاء الحساب: $e');
    }

    final user = app.AppUser(
      id: userCredential.user!.uid,
      fullName: fullName,
      phone: phone ?? '',
      email: email,
      createdAt: DateTime.now(),
    );

    await _firebaseService.saveUser(user.toMap());
    return user;
  }

  // =================== تسجيل الدخول بالبريد الإلكتروني ===================

  Future<app.AppUser> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    try {
      final userCredential = await _firebaseService.auth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          );

      final userData = await _firebaseService.getUser(
        userCredential.user!.uid,
      );
      if (userData != null) {
        return app.AppUser.fromMap(userData);
      }

      return app.AppUser(
        id: userCredential.user!.uid,
        fullName: 'مستخدم',
        email: email,
        phone: '',
      );
    } catch (e) {
      throw Exception('فشل تسجيل الدخول: $e');
    }
  }

  // =================== تسجيل الخروج ===================

  Future<void> logout() async {
    _clearOtpSession();
    await _firebaseService.auth.signOut();
  }

  // =================== الحالة ===================

  Stream<User?> get authStateChanges =>
      _firebaseService.auth.authStateChanges();

  User? get currentUser => _firebaseService.auth.currentUser;
  bool get isLoggedIn => _firebaseService.auth.currentUser != null;

  // =================== إعادة تعيين كلمة المرور ===================

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseService.auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('فشل إرسال رابط إعادة التعيين: $e');
    }
  }

  // =================== تحديث الملف الشخصي ===================

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? profileImage,
    String? phone,
  }) async {
    final Map<String, dynamic> updates = {};
    if (fullName != null) updates['fullName'] = fullName;
    if (profileImage != null) updates['profileImage'] = profileImage;
    if (phone != null) updates['phone'] = phone;

    if (updates.isNotEmpty) {
      await _firebaseService.firestore
          .collection('users')
          .doc(userId)
          .update(updates);
    }
  }
}
