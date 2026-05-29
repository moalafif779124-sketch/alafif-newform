import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user.dart' as app;
import 'firebase_service.dart';

/// خدمة المصادقة - تدعم الدخول بالجوال (OTP) والبريد الإلكتروني
class AuthService {
  final FirebaseService _firebaseService = FirebaseService();

  // =================== التحقق من الجوال (OTP) ===================

  /// إرسال رمز التحقق إلى رقم الجوال
  Future<ConfirmationResult> verifyWithPhone(String phone) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    // استخدام إعادة التحقق (reCaptcha) التلقائي
    try {
      final result = await _firebaseService.auth.signInWithPhoneNumber(phone);
      return result;
    } catch (e) {
      throw Exception('فشل إرسال رمز التحقق: $e');
    }
  }

  /// التحقق من رمز OTP وإتمام تسجيل الدخول
  Future<app.AppUser> confirmOtp({
    required ConfirmationResult result,
    required String otp,
    String? fullName, // مطلوب للمستخدم الجديد
  }) async {
    try {
      final userCredential = await result.confirm(otp);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('لم يتم التعرف على المستخدم');
      }

      // التحقق مما إذا كان المستخدم موجوداً في Firestore
      final existingUser = await _firebaseService.getUser(firebaseUser.uid);

      if (existingUser != null) {
        return app.AppUser.fromMap(existingUser);
      }

      // مستخدم جديد - نحتاج اسم كامل
      if (fullName == null || fullName.isEmpty) {
        throw Exception('مطلوب الاسم الكامل للمستخدم الجديد');
      }

      final user = app.AppUser(
        id: firebaseUser.uid,
        fullName: fullName,
        phone: firebaseUser.phoneNumber ?? '',
        email: firebaseUser.email ?? '',
        createdAt: DateTime.now(),
      );

      await _firebaseService.saveUser(user.toMap());
      return user;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('فشل التحقق من الرمز: $e');
    }
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
