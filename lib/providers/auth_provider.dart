import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

/// مزود حالة المصادقة - يدعم OTP عبر واتساب والبريد الإلكتروني
/// يحفظ حالة OTP في SharedPreferences لضمان الصمود حتى لو انوقف التطبيق
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  
  // حالة OTP
  bool _otpSent = false;
  String? _otpCode;
  String? _whatsappUrl;
  String? _pendingPhone;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get userId => _user?.id;
  bool get otpSent => _otpSent;
  String? get otpCode => _otpCode;
  String? get whatsappUrl => _whatsappUrl;
  String? get pendingPhone => _pendingPhone;

  // =================== حفظ/استرجاع OTP من SharedPreferences ===================

  Future<void> _saveOtpSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_otpCode != null) await prefs.setString('otp_code', _otpCode!);
      if (_pendingPhone != null) await prefs.setString('pending_phone', _pendingPhone!);
      await prefs.setBool('otp_sent', _otpSent);
      debugPrint('💾 OTP session saved to SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Failed to save OTP session: $e');
    }
  }

  Future<void> _clearOtpSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('otp_code');
      await prefs.remove('pending_phone');
      await prefs.remove('otp_sent');
      debugPrint('🗑️ OTP session cleared from SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Failed to clear OTP session: $e');
    }
  }

  /// استرجاع جلسة OTP من SharedPreferences — يُستدعى عند فتح شاشة OTP
  Future<void> restoreOtpSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final otpCode = prefs.getString('otp_code');
      final pendingPhone = prefs.getString('pending_phone');
      final otpSent = prefs.getBool('otp_sent');

      if (otpCode != null && pendingPhone != null) {
        _otpCode = otpCode;
        _pendingPhone = pendingPhone;
        _otpSent = otpSent ?? true;
        notifyListeners();
        debugPrint('♻️ OTP session restored: phone=$pendingPhone, code=$otpCode');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to restore OTP session: $e');
    }
  }

  // =================== التهيئة ===================

  Future<void> initialize() async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUser(firebaseUser.uid);
      } else {
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUser(String uid) async {
    try {
      final userData = await _firebaseService.getUser(uid);
      if (userData != null) {
        _user = AppUser.fromMap(userData);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  // =================== الدخول بالجوال (OTP عبر واتساب) ===================

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    _otpSent = false;
    _otpCode = null;
    _whatsappUrl = null;
    _pendingPhone = phone;
    notifyListeners();

    try {
      final result = await _authService.sendOtp(phone);
      
      _otpCode = result['otp'];
      _whatsappUrl = result['whatsappUrl'];
      _pendingPhone = result['phone'];
      _otpSent = true;
      _isLoading = false;
      
      // 💾 حفظ جلسة OTP في SharedPreferences قبل فتح واتساب
      await _saveOtpSession();
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// إعادة إرسال OTP
  Future<bool> resendOtp() async {
    if (_pendingPhone == null) {
      _error = 'الرجاء إدخال رقم الجوال أولاً';
      notifyListeners();
      return false;
    }
    return sendOtp(_pendingPhone!);
  }

  /// تأكيد رمز OTP وإتمام تسجيل الدخول
  Future<bool> confirmOtp({
    required String otp,
    String? fullName,
  }) async {
    // ♻️ استرجاع جلسة OTP من SharedPreferences إن كانت ضاعت من الذاكرة
    if (_otpCode == null || _pendingPhone == null) {
      await restoreOtpSession();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.createOrLoginUser(
        otp: otp,
        expectedOtp: _otpCode ?? '',
        phone: _pendingPhone ?? '',
        fullName: fullName,
      );
      
      // 🗑️ مسح جلسة OTP بعد نجاح تسجيل الدخول
      await _clearOtpSession();
      
      _otpSent = false;
      _otpCode = null;
      _whatsappUrl = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// إلغاء عملية OTP
  void cancelOtp() {
    _clearOtpSession();
    _authService.cancelOtp();
    _otpSent = false;
    _otpCode = null;
    _whatsappUrl = null;
    _pendingPhone = null;
    _error = null;
    notifyListeners();
  }

  // =================== التسجيل بالبريد الإلكتروني ===================

  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.registerWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =================== تسجيل الدخول بالبريد الإلكتروني ===================

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =================== تسجيل الخروج ===================

  Future<void> logout() async {
    await _clearOtpSession();
    await _authService.logout();
    _user = null;
    _otpSent = false;
    _otpCode = null;
    _whatsappUrl = null;
    _pendingPhone = null;
    notifyListeners();
  }

  // =================== تحديث الملف الشخصي ===================

  Future<void> updateProfile({
    String? fullName,
    String? profileImage,
  }) async {
    if (_user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.updateProfile(
        userId: _user!.id,
        fullName: fullName,
        profileImage: profileImage,
      );

      if (fullName != null) {
        _user = AppUser(
          id: _user!.id,
          fullName: fullName,
          phone: _user!.phone,
          email: _user!.email,
          profileImage: profileImage ?? _user!.profileImage,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // =================== مسح الأخطاء ===================

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
