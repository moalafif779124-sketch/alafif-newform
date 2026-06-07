import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

/// مزود حالة المنتجات المفضلة (قائمة الرغبات)
class WishlistProvider with ChangeNotifier {
  List<String> _wishlistIds = [];
  bool _isLoading = false;

  List<String> get wishlistIds => _wishlistIds;
  bool get isLoading => _isLoading;
  int get count => _wishlistIds.length;

  bool isWishlisted(String productId) => _wishlistIds.contains(productId);

  /// تحميل المفضلة من SharedPreferences
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

  /// حفظ المفضلة في SharedPreferences
  Future<void> _saveWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wishlist_ids', jsonEncode(_wishlistIds));
    } catch (e) {
      debugPrint('Error saving wishlist: $e');
    }
  }

  /// مسح المفضلة
  Future<void> clearWishlist() async {
    _wishlistIds.clear();
    await _saveWishlist();
    notifyListeners();
  }
}
