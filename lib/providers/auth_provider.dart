import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

/// مزود حالة المصادقة - يدعم OTP عبر واتساب والبريد الإلكتروني
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  
  // حالة OTP
  bool _otpSent = false;
  String? _otpCode; // رمز الـ OTP (للعرض فقط)
  String? _whatsappUrl; // رابط واتساب
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

  /// توليد OTP وتحضير رابط واتساب (لا يرسل شيء، يفتح واتساب فقط)
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.createOrLoginUser(
        otp: otp,
        fullName: fullName,
      );
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
