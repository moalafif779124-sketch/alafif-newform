import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user.dart';
import 'firebase_service.dart';

/// خدمة المصادقة والتحقق من الهوية
class AuthService {
  final FirebaseService _firebaseService = FirebaseService();

  // =================== التسجيل ===================

  Future<AppUser> registerWithPhone({
    required String phone,
    required String fullName,
    required String password,
  }) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    UserCredential userCredential;
    try {
      // Using email-like format for Firebase Auth since we need a simple auth
      final email = 'user_${phone.replaceAll(RegExp(r'[^0-9]'), '')}@alafif.app';
      userCredential = await _firebaseService.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('فشل إنشاء الحساب: $e');
    }

    final user = AppUser(
      id: userCredential.user!.uid,
      fullName: fullName,
      phone: phone,
      email: 'user_${phone.replaceAll(RegExp(r'[^0-9]'), '')}@alafif.app',
      createdAt: DateTime.now(),
    );

    // حفظ بيانات المستخدم في Firestore
    await _firebaseService.saveUser(user.toMap());

    return user;
  }

  // =================== تسجيل الدخول ===================

  Future<AppUser> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    final email = 'user_${phone.replaceAll(RegExp(r'[^0-9]'), '')}@alafif.app';
    
    try {
      final userCredential = await _firebaseService.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userData = await _firebaseService.getUser(userCredential.user!.uid);
      if (userData != null) {
        return AppUser.fromMap(userData);
      }

      return AppUser(
        id: userCredential.user!.uid,
        fullName: 'مستخدم',
        phone: phone,
      );
    } catch (e) {
      throw Exception('فشل تسجيل الدخول: $e');
    }
  }

  // =================== تسجيل الخروج ===================

  Future<void> logout() async {
    await _firebaseService.auth.signOut();
  }

  // =================== التحقق من حالة المصادقة ===================

  Stream<User?> get authStateChanges => _firebaseService.auth.authStateChanges();

  User? get currentUser => _firebaseService.auth.currentUser;

  bool get isLoggedIn => _firebaseService.auth.currentUser != null;

  // =================== إعادة تعيين كلمة المرور ===================

  Future<void> resetPassword(String phone) async {
    final email = 'user_${phone.replaceAll(RegExp(r'[^0-9]'), '')}@alafif.app';
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
  }) async {
    final Map<String, dynamic> updates = {};
    if (fullName != null) updates['fullName'] = fullName;
    if (profileImage != null) updates['profileImage'] = profileImage;

    if (updates.isNotEmpty) {
      await _firebaseService.firestore
          .collection('users')
          .doc(userId)
          .update(updates);
    }
  }
}
