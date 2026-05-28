import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

/// مزود حالة المصادقة والمستخدم
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  AppUser? _user;
  bool _isLoading = false;
  String? _error;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get userId => _user?.id;

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

  // =================== التسجيل ===================

  Future<bool> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.registerWithPhone(
        phone: phone,
        fullName: fullName,
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

  // =================== تسجيل الدخول ===================

  Future<bool> login({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.loginWithPhone(
        phone: phone,
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
