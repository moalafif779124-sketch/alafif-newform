import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/bundle_pricing.dart';
import '../services/firebase_service.dart';
import '../config/constants.dart';
import '../config/delivery_config.dart';

/// مزود حالة سلة التسوق
class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isLoading = false;
  String? _userId;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get totalEffectiveSubtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalEffectivePrice);

  /// ملخص أطقم السلة (القطع القادمة من توصية المصمم الذكي أو من طقم منسّق).
  BundleSummary get bundleSummary => BundlePricing.summarize(_items);

  /// خصم الطقم المستحق على السلة (10% لقطعتين، 15% لثلاث قطع أو أكثر).
  double get discountAmount => bundleSummary.discountAmount;

  /// الضريبة تُحسب على المبلغ بعد خصم الطقم.
  double get tax => (subtotal - discountAmount) * AppConstants.taxRate;
  /// الشحن يساوي ما ستفرضه شاشة الدفع فعلياً لعنوان المحافظة الافتراضي
  /// (مجاني ≥ 50,000). سابقاً كانت السلة تستخدم AppConstants.shippingCost
  /// الثابت (3000) بينما الدفع يستخدم تعرفة المحافظة (صنعاء=2000) فيختلف
  /// الإجمالي بين السلة والدفع.
  double get shipping =>
      DeliveryConfig.getShippingCost(DeliveryConfig.defaultCityId,
          subtotal: subtotal);

  /// المبلغ النهائي المستحق — الخصم مخصوم فعلياً لا معروضاً فقط.
  double get totalAmount => subtotal + tax + shipping - discountAmount;

  /// الاسم القديم محفوظ للتوافق — ويشمل الخصم الآن.
  double get total => totalAmount;

  bool get hasItems => _items.isNotEmpty;

  // =================== إدارة العناصر ===================

  void addItem(CartItem item) {
    final index = _items.indexWhere(
      (i) => i.product.id == item.product.id && i.size == item.size && i.color == item.color,
    );

    if (index >= 0) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }

    _saveToLocal();
    _syncToFirebase();
    notifyListeners();
  }

  /// إضافة عدة عناصر دفعة واحدة (إطلالة كاملة مثلاً).
  ///
  /// كانت إضافة كل قطعة على حدة تستدعي: كتابة محلية + كتابة Firestore +
  /// notifyListeners() لكل قطعة — أي 3-4 كتابات سحابية وإعادة بناء كامل
  /// للواجهة في تتابع سريع، وهو ما يسبب تجمّد الواجهة بعد «أضف الإطلالة
  /// كاملة إلى السلة». هنا نجمع الكل في الذاكرة ثم نكتب/نزامن/نُخطر مرة واحدة.
  void addItems(List<CartItem> newItems) {
    if (newItems.isEmpty) return;

    for (final item in newItems) {
      final index = _items.indexWhere(
        (i) =>
            i.product.id == item.product.id &&
            i.size == item.size &&
            i.color == item.color,
      );
      if (index >= 0) {
        _items[index].quantity += item.quantity;
      } else {
        _items.add(item);
      }
    }

    _saveToLocal();
    _syncToFirebase();
    notifyListeners();
  }

  void removeItem(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    _saveToLocal();
    _syncToFirebase();
    notifyListeners();
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      _saveToLocal();
      _syncToFirebase();
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _saveToLocal();
    _syncToFirebase();
    notifyListeners();
  }

  bool isInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  int getProductQuantity(String productId) {
    return _items
        .where((item) => item.product.id == productId)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  // =================== المزامنة ===================

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _loadFromFirebase();
    } else {
      _loadFromLocal();
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = _items.map((item) => {
        'id': item.id,
        'productId': item.product.id,
        'size': item.size,
        'color': item.color,
        'colorHex': item.colorHex,
        'bundleSource': item.bundleSource,
        'bundleGroupId': item.bundleGroupId,
        'quantity': item.quantity,
      }).toList();
      await prefs.setString('cart_items', jsonEncode(itemsJson));
    } catch (e) {
      debugPrint('Error saving cart to local: $e');
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      if (cartJson != null) {
        final itemsList = jsonDecode(cartJson) as List;
        // Note: products need to be loaded separately
        // This is a simplified version
      }
    } catch (e) {
      debugPrint('Error loading cart from local: $e');
    }
  }

  Future<void> _syncToFirebase() async {
    if (_userId == null) return;
    try {
      final service = FirebaseService();
      if (service.isInitialized) {
        await service.saveCart(
          _userId!,
          _items.map((item) => item.toMap()).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error syncing cart to Firebase: $e');
    }
  }

  Future<void> _loadFromFirebase() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final service = FirebaseService();
      if (service.isInitialized) {
        final cartData = await service.getCart(_userId!);
        if (cartData != null) {
          // تفريغ القائمة قبل التحميل — وإلا تُضاف عناصر السلة السحابية
          // فوق العناصر الحالية في كل تشغيل، فتتضخم السلة وتصبح القراءات
          // (حاصل × عدد العناصر) بطيئة جداً وتُثقل الواجهة.
          _items.clear();

          // تحميل بيانات كل منتج (بالتوازي بدل التتابع)
          final productFutures = cartData
              .map((itemData) => service.getProduct(itemData['productId']))
              .toList();
          final products = await Future.wait(productFutures);

          for (var i = 0; i < cartData.length; i++) {
            final itemData = cartData[i];
            final productData = products[i];
            if (productData == null) continue;
            final product = Product.fromMap(productData);
            _items.add(
              CartItem(
                id: itemData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                product: product,
                size: itemData['size'] ?? '',
                color: itemData['color'] ?? '',
                colorHex: itemData['colorHex'] ?? '#000000',
                bundleSource: itemData['bundleSource'] ?? '',
                bundleGroupId: itemData['bundleGroupId'] ?? '',
                quantity: itemData['quantity'] ?? 1,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cart from Firebase: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
