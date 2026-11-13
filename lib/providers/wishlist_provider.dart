import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../services/firebase_service.dart';

/// مزود حالة المنتجات المفضلة (قائمة الرغبات)
class WishlistProvider with ChangeNotifier {
  List<String> _wishlistIds = [];
  bool _isLoading = false;
  String? _userId;

  List<String> get wishlistIds => _wishlistIds;
  bool get isLoading => _isLoading;
  int get count => _wishlistIds.length;

  bool isWishlisted(String productId) => _wishlistIds.contains(productId);

  /// تحميل المفضلة من SharedPreferences + Firestore
  Future<void> loadWishlist() async {
    _isLoading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('wishlist_ids');
      if (saved != null) {
        _wishlistIds = List<String>.from(jsonDecode(saved));
      }
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// تبديل حالة المفضلة لمنتج
  Future<void> toggleWishlist(String productId) async {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
    } else {
      _wishlistIds.add(productId);
    }
    await _saveWishlist();
    notifyListeners();
  }

  /// إضافة منتج إلى المفضلة
  Future<void> addToWishlist(String productId) async {
    if (!_wishlistIds.contains(productId)) {
      _wishlistIds.add(productId);
      await _saveWishlist();
      notifyListeners();
    }
  }

  /// إزالة منتج من المفضلة
  Future<void> removeFromWishlist(String productId) async {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
      await _saveWishlist();
      notifyListeners();
    }
  }

  /// الحصول على المنتجات المفضلة من ProductProvider
  List<Product> getWishlistProducts(List<Product> allProducts) {
    return allProducts.where((p) => _wishlistIds.contains(p.id)).toList();
  }

  // =================== المزامنة ===================

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _loadFromFirebase();
    } else {
      loadWishlist();
    }
  }

  /// حفظ المفضلة في SharedPreferences + Firestore
  Future<void> _saveWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wishlist_ids', jsonEncode(_wishlistIds));
    } catch (e) {
      debugPrint('Error saving wishlist to local: $e');
    }
    _syncToFirebase();
  }

  Future<void> _syncToFirebase() async {
    if (_userId == null) return;
    try {
      final service = FirebaseService();
      if (service.isInitialized) {
        await service.saveWishlist(_userId!, _wishlistIds);
      }
    } catch (e) {
      debugPrint('Error syncing wishlist to Firebase: $e');
    }
  }

  Future<void> _loadFromFirebase() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      // 1) اقرأ المفضلة المحفوظة محلياً أولاً — المصدر الأدنى المضمون حتى لو
      //    تعذّرت كتابة Firestore (قواعد/اتصال). بدون هذا كانت المفضلة تُفرَّغ
      //    عند إعادة تشغيل التطبيق إن لم يوجد مستند سحابي.
      final prefs = await SharedPreferences.getInstance();
      final savedLocal = prefs.getString('wishlist_ids');
      final local = savedLocal != null
          ? List<String>.from(jsonDecode(savedLocal))
          : <String>[];

      // 2) حاول قراءة السحابي إن أمكن
      List<String>? remote;
      final service = FirebaseService();
      if (service.isInitialized) {
        remote = await service.getWishlist(_userId!);
      }

      // 3) دمج المحلي والسحابي (اتحاد) — لا نُسقط المحلي إن كان السحابي فارغاً
      final merged = <String>{...local, if (remote != null) ...remote};
      _wishlistIds = merged.toList();

      // 4) أعد حفظ النتيجة محلياً (وسحابياً بأفضل جهد) لتثبيت الدمج
      await _saveWishlist();
    } catch (e) {
      debugPrint('Error loading wishlist from Firebase: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// مسح المفضلة
  Future<void> clearWishlist() async {
    _wishlistIds.clear();
    await _saveWishlist();
    if (_userId != null) {
      try {
        final service = FirebaseService();
        if (service.isInitialized) {
          await service.clearWishlist(_userId!);
        }
      } catch (e) {
        debugPrint('Error clearing wishlist from Firebase: $e');
      }
    }
    notifyListeners();
  }
}
