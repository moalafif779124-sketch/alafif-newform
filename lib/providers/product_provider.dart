import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/banner.dart';
import '../services/firebase_service.dart';
import '../services/cache_service.dart';
import '../config/constants.dart';

/// مزود حالة المنتجات والفئات — مع تحميل مُقسّم (pagination)
class ProductProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  // =========== البيانات الكاملة (تُحمّل عند الحاجة فقط) ===========
  List<Product> _products = [];
  List<Category> _categories = [];
  List<BannerModel> _banners = [];
  List<Product> _featuredProducts = [];
  List<Product> _newArrivals = [];

  // =========== حالة التحميل المُقسّم (pagination) ===========
  static const int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedCategoryId = '';
  String _sortBy = 'newest';

  // =========== حالة الفلاتر المتقدمة ===========
  double _minPrice = 0;
  double _maxPrice = 0;
  Set<String> _selectedSizes = {};
  Set<String> _selectedColors = {};
  String _selectedMaterial = '';
  bool _discountOnly = false;

  // =========== أعلام التحميل الجزئي ===========
  bool _categoriesLoaded = false;
  bool _bannersLoaded = false;

  // =================== Getters ===================

  List<Product> get products => _products;
  List<Product> get filteredProducts => _applyFilters(_products);
  List<Category> get categories => _categories;
  List<BannerModel> get banners => _banners;
  List<Product> get featuredProducts => _featuredProducts;
  List<Product> get newArrivals => _newArrivals;

  /// منتجات العروض والتخفيضات (عبر خيار العرض displayOptions.offers)
  List<Product> get offerProducts =>
      products.where((p) => p.isSpecialOffer).toList();
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategoryId => _selectedCategoryId;
  String get sortBy => _sortBy;
  double get minPrice => _minPrice;
  double get maxPrice => _maxPrice;
  Set<String> get selectedSizes => _selectedSizes;
  Set<String> get selectedColors => _selectedColors;
  String get selectedMaterial => _selectedMaterial;
  bool get discountOnly => _discountOnly;
  bool get hasActiveFilters =>
      _minPrice > 0 ||
      _maxPrice > 0 ||
      _selectedSizes.isNotEmpty ||
      _selectedColors.isNotEmpty ||
      _selectedMaterial.isNotEmpty ||
      _discountOnly;

  /// جميع المقاسات المتوفرة في المنتجات
  Set<String> get availableSizes =>
      _products.expand((p) => p.sizes).toSet();

  /// جميع الألوان المتوفرة في المنتجات (hex codes فريدة)
  Set<String> get availableColors =>
      _products.expand((p) => p.colors).toSet();

  /// جميع الخامات المتوفرة في المنتجات
  Set<String> get availableMaterials =>
      _products.map((p) => p.material).where((m) => m.isNotEmpty).toSet();

  // =================== التهيئة السريعة (بدون تحميل المنتجات) ===================

  /// تهيئة سريعة — تعرض البيانات المخزنة محلياً فوراً ثم تحمّل من Firestore في الخلفية
  /// لا تُحمّل المنتجات هنا — يتم تحميلها عند عرض الشاشة الرئيسية
  Future<void> initialize() async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }

    // ===== الخطوة 1: اقرأ من الكاش المحلي (صفر انتظار) =====
    await _restoreFromCache();

    // ===== الخطوة 2: حدّث من Firestore في الخلفية =====
    await Future.wait([
      _loadCategoriesOnce().catchError((e) {
        debugPrint('Error loading categories: $e');
        _categories = AppConstants.categories
            .asMap()
            .entries
            .map((e) => Category(
                  id: e.value['id'],
                  name: e.value['name'],
                  nameEn: e.value['nameEn'],
                  icon: e.value['icon'],
                  order: e.key,
                ))
            .toList();
      }),
      _loadBannersOnce().catchError((e) {
        debugPrint('Error loading banners: $e');
        // لا تستخدم بينرات تجريبية — اترك المصفوفة فارغة
      }),
    ]);
  }

  /// استرجاع البيانات المخزنة محلياً (بانرات + منتجات)
  Future<void> _restoreFromCache() async {
    try {
      final cachedBanners = await CacheService.instance.getBanners();
      if (cachedBanners != null && cachedBanners.isNotEmpty) {
        _banners =
            cachedBanners.map((data) => BannerModel.fromMap(data)).toList();
        // لا نضبط _bannersLoaded = true هنا — نريد تحديث البانرات من Firestore لاحقاً
        notifyListeners();
      }

      final cachedProducts = await CacheService.instance.getProducts();
      if (cachedProducts != null && cachedProducts.isNotEmpty) {
        _products =
            cachedProducts.map((data) => Product.fromMap(data)).toList();
        _recomputeCollections();
        _hasMore = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Cache restore failed: $e');
    }
  }

  /// تحميل الفئات مرة واحدة فقط
  Future<void> _loadCategoriesOnce() async {
    if (_categoriesLoaded) return;
    final categoriesData = await _firebaseService.getCategories();
    _categories =
        categoriesData.map((data) => Category.fromMap(data)).toList();
    _sortCategoriesByAdminOrder(_categories);
    _categoriesLoaded = true;
  }

  /// ترتيب الفئات حسب حقل `order` الذي يضبطه الأدمن (الأصغر أولاً).
  /// ترتيب مستقر: عند التساوي أو غياب الحقل يبقى الترتيب الأصلي كما هو.
  static void _sortCategoriesByAdminOrder(List<Category> categories) {
    final indexed = [
      for (var i = 0; i < categories.length; i++) (index: i, item: categories[i]),
    ]..sort((a, b) {
        final byOrder = a.item.order.compareTo(b.item.order);
        return byOrder != 0 ? byOrder : a.index.compareTo(b.index);
      });
    for (var i = 0; i < categories.length; i++) {
      categories[i] = indexed[i].item;
    }
  }

  /// تحميل البانرات مرة واحدة فقط — مع حفظ في الكاش
  Future<void> _loadBannersOnce() async {
    if (_bannersLoaded) return;
    final bannersData = await _firebaseService.getActiveBanners();
    _banners = bannersData.map((data) => BannerModel.fromMap(data)).toList();
    _bannersLoaded = true;
    // حفظ في الكاش المحلي
    await CacheService.instance.saveBanners(bannersData);
    notifyListeners();
  }

  // =================== المزامنة الفورية (Real-time Sync) ===================
  // يستمع لتغييرات Firestore من تطبيق الإدارة (alafif-admin)
  // أي تعديل على المنتجات أو البانرات ينعكس فوراً في تطبيق المتجر

  StreamSubscription<List<Map<String, dynamic>>>? _bannersSub;
  StreamSubscription<List<Map<String, dynamic>>>? _productsSub;
  bool _realtimeStarted = false;

  /// بدء الاستماع الفوري لتغييرات Firestore
  void startRealtimeSync() {
    if (_realtimeStarted) return;
    _realtimeStarted = true;

    // بث البانرات — أي تغيير من لوحة التحكم يظهر فوراً
    _bannersSub = _firebaseService.getBannersStream().listen((data) {
      _banners = data.map((m) => BannerModel.fromMap(m)).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('⚠️ Banners stream error: $e');
    });

    // بث المنتجات — تحديث/إضافة/حذف من لوحة التحكم ينعكس فوراً
    _productsSub = _firebaseService.getProductsStream().listen((data) {
      _products = data.map((m) => Product.fromMap(m)).toList();
      _recomputeCollections();
      // القائمة الكاملة وصلت — لا حاجة للتحميل التصفحي بعد الآن
      _hasMore = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('⚠️ Products stream error: $e');
    });
  }

  /// إيقاف الاستماع الفوري (اختياري)
  void stopRealtimeSync() {
    _bannersSub?.cancel();
    _productsSub?.cancel();
    _realtimeStarted = false;
  }


  // =================== تحميل المنتجات المُقسّم (Pagination) ===================

  /// تحميل الدفعة الأولى — يُظهر العيّنات فوراً ثم يستبدلها بالبيانات الحقيقية
  Future<void> loadInitialProducts() async {
    _hasMore = true;
    _lastDocument = null;

    // ===== الخطوة 1: لا بيانات تجريبية — الكاش المحلي إن وُجد، وإلا مؤشر تحميل =====
    _seedCategoriesIfEmpty();
    if (_products.isEmpty) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    // ===== الخطوة 2: حمّل المنتجات الحقيقية من Firestore =====
    try {
      final result = await _firebaseService.getProducts(
        limit: _pageSize,
        sortBy: _sortBy == 'newest' ? null : _sortBy,
      );

      final productsData = result['products'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'] as DocumentSnapshot?;
      _hasMore = result['hasMore'] as bool;

      _isLoading = false;
      _products = productsData.map((data) => Product.fromMap(data)).toList();
      _recomputeCollections();
      notifyListeners();

      // ===== الخطوة 3: حفظ أول 15 منتج في الكاش المحلي =====
      final toCache = productsData.take(15).toList();
      if (toCache.isNotEmpty) {
        await CacheService.instance.saveProducts(toCache);
      }
    } catch (e) {
      debugPrint('Error loading initial products: $e');
      // أبقِ ما في الكاش (إن وجد) وأوقف الترقيم — لا نعرض بيانات وهمية
      _isLoading = false;
      _hasMore = false;
      _error = 'تعذّر تحميل المنتجات';
      notifyListeners();
    }
  }

  /// تحميل الدفعة التالية (التمرير اللانهائي)
  Future<void> loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _firebaseService.getProducts(
        limit: _pageSize,
        lastDocument: _lastDocument,
        sortBy: _sortBy == 'newest' ? null : _sortBy,
      );

      final productsData = result['products'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'] as DocumentSnapshot?;
      _hasMore = result['hasMore'] as bool;

      final newProducts =
          productsData.map((data) => Product.fromMap(data)).toList();
      // حماية: لا تخلط أبداً بيانات وهمية (sample_) مع منتجات المتجر الحقيقية
      _products.removeWhere((p) => p.id.startsWith('sample_'));
      _products.addAll(newProducts);
      _recomputeCollections();
    } catch (e) {
      debugPrint('Error loading more products: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// إعادة حساب القوائم المشتقة
  void _recomputeCollections() {
    _featuredProducts = _products.where((p) => p.isFeatured).toList();
    _newArrivals = _products.where((p) => p.isNewArrival).toList();
  }

  /// التحميل المسبق للصور المصغرة — يُستدعى من الشاشات عند توفر Context
  static Future<void> precacheProductThumbnails(
    BuildContext context,
    List<Product> products, {
    int max = 10,
  }) async {
    final toCache = products.take(max).toList();
    for (final product in toCache) {
      if (product.images.isNotEmpty) {
        final url = product.images.first;
        if (url.isNotEmpty && !url.startsWith('data:image/')) {
          // الصور Base64 لا تحتاج تحميل مسبق — مخزنة في الذاكرة (b64Cache)
          try {
            await precacheImage(
              CachedNetworkImageProvider(url),
              context,
              onError: (_, __) {},
            );
          } catch (_) {}
        }
      }
    }
  }

  /// إعادة تحميل كل شيء (للتحديث بالسحب)
  Future<void> loadAll() async {
    // مسح حالة التحميل المُقسّم
    _lastDocument = null;
    _hasMore = true;
    return loadInitialProducts();
  }

  // =================== تهيئة أولية (بدون بيانات وهمية) ===================

  /// تعبئة الفئات الافتراضية فقط عندما لا توجد فئات من Firestore بعد،
  /// حتى تظهر شرائح الفئات في أول إطار. المنتجات لا تُولَّد إطلاقاً:
  /// ما يظهر في المتجر هو بيانات الأدمن فقط (من Firestore أو الكاش).
  void _seedCategoriesIfEmpty() {
    if (_categories.isNotEmpty) return;
    _categories = AppConstants.categories
        .asMap()
        .entries
        .map((e) => Category(
              id: e.value['id'],
              name: e.value['name'],
              nameEn: e.value['nameEn'],
              icon: e.value['icon'],
              order: e.key,
            ))
        .toList();
  }

  // =================== الفلترة والفرز ===================

  List<Product> _applyFilters(List<Product> products) {
    var result = List<Product>.from(products);

    // فلترة حسب خيار العرض (جديد/عروض/ترند — من أيقونات الصفحة الرئيسية)
    switch (_displayFilter) {
      case 'new':
        result = result.where((p) => p.isNewAlafif).toList();
      case 'offers':
        result = result.where((p) => p.isSpecialOffer).toList();
      case 'trends':
        result = result.where((p) => p.isFeatured).toList();
    }

    // فلترة حسب الفئة
    if (_selectedCategoryId.isNotEmpty) {
      result = result.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    // فلترة حسب البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query) ||
              p.brand.toLowerCase().contains(query) ||
              p.categoryName.toLowerCase().contains(query) ||
              p.tags.any((tag) => tag.toLowerCase().contains(query)))
          .toList();
    }

    // فلترة حسب نطاق السعر
    if (_minPrice > 0) {
      result = result.where((p) => p.price >= _minPrice).toList();
    }
    if (_maxPrice > 0) {
      result = result.where((p) => p.price <= _maxPrice).toList();
    }

    // فلترة حسب المقاسات
    if (_selectedSizes.isNotEmpty) {
      result = result
          .where((p) => p.sizes.any((s) => _selectedSizes.contains(s)))
          .toList();
    }

    // فلترة حسب الألوان
    if (_selectedColors.isNotEmpty) {
      result = result
          .where((p) => p.colors.any((c) => _selectedColors.contains(c)))
          .toList();
    }

    // فلترة حسب الخامة
    if (_selectedMaterial.isNotEmpty) {
      result = result
          .where((p) => p.material.toLowerCase() == _selectedMaterial.toLowerCase())
          .toList();
    }

    // فلترة العروض فقط
    if (_discountOnly) {
      result = result.where((p) => p.hasDiscount).toList();
    }

    // ترتيب
    switch (_sortBy) {
      case 'price_asc':
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'popular':
        result.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
      case 'name':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'newest':
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return result;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  /// فلتر عرض محدد: null | 'new' | 'offers' | 'trends'
  String? _displayFilter;

  String? get displayFilter => _displayFilter;

  /// تعيين فلتر العرض (من أيقونات الفئات السريعة في الصفحة الرئيسية)
  void setDisplayFilter(String? filter) {
    _displayFilter = filter;
    notifyListeners();
  }

  // =================== فلاتر متقدمة ===================

  /// تعيين نطاق السعر (0 يعني غير محدود)
  void setPriceRange(double min, double max) {
    _minPrice = min;
    _maxPrice = max;
    notifyListeners();
  }

  /// تبديل اختيار مقاس
  void toggleSize(String size) {
    if (_selectedSizes.contains(size)) {
      _selectedSizes.remove(size);
    } else {
      _selectedSizes.add(size);
    }
    notifyListeners();
  }

  /// تبديل اختيار لون (hex code)
  void toggleColor(String hexColor) {
    if (_selectedColors.contains(hexColor)) {
      _selectedColors.remove(hexColor);
    } else {
      _selectedColors.add(hexColor);
    }
    notifyListeners();
  }

  /// تعيين فلتر الخامة (فارغ = الكل)
  void setMaterial(String material) {
    _selectedMaterial = _selectedMaterial == material ? '' : material;
    notifyListeners();
  }

  /// تبديل فلتر العروض فقط
  void setDiscountOnly(bool value) {
    _discountOnly = value;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = '';
    _sortBy = 'newest';
    _minPrice = 0;
    _maxPrice = 0;
    _selectedSizes = {};
    _selectedColors = {};
    _selectedMaterial = '';
    _discountOnly = false;
    notifyListeners();
  }

  // =================== تفاصيل المنتج ===================

  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Product> getRelatedProducts(String productId) {
    final product = getProductById(productId);
    if (product == null) return [];
    return _products
        .where((p) => p.categoryId == product.categoryId && p.id != productId)
        .take(6)
        .toList();
  }

  List<Product> searchProducts(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.categoryName.toLowerCase().contains(q))
        .take(10)
        .toList();
  }
}
