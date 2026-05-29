import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

/// مزود حالة المصادقة - يدعم الجوال (OTP) والبريد الإلكتروني
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  ConfirmationResult? _confirmationResult;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get userId => _user?.id;
  bool get otpSent => _confirmationResult != null;

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

  // =================== الدخول بالجوال (OTP) ===================

  /// إرسال رمز التحقق إلى رقم الجوال
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    _confirmationResult = null;
    notifyListeners();

    try {
      _confirmationResult = await _authService.verifyWithPhone(phone);
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

  /// تأكيد رمز OTP وإتمام تسجيل الدخول
  Future<bool> confirmOtp({
    required String otp,
    String? fullName,
  }) async {
    if (_confirmationResult == null) {
      _error = 'الرجاء إرسال رمز التحقق أولاً';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.confirmOtp(
        result: _confirmationResult!,
        otp: otp,
        fullName: fullName,
      );
      _confirmationResult = null;
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
    _confirmationResult = null;
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
    _confirmationResult = null;
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
