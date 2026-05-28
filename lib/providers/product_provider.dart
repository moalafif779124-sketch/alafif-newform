import 'dart:math';
import 'package:flutter/foundation.dart' hide Category;
import '../models/product.dart';
import '../models/category.dart';
import '../models/banner.dart';
import '../services/firebase_service.dart';
import '../config/constants.dart';

/// مزود حالة المنتجات والفئات
class ProductProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<BannerModel> _banners = [];
  List<Product> _featuredProducts = [];
  List<Product> _newArrivals = [];

  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedCategoryId = '';
  String _sortBy = 'newest';

  // =================== Getters ===================

  List<Product> get products => _products;
  List<Product> get filteredProducts => _applyFilters(_products);
  List<Category> get categories => _categories;
  List<BannerModel> get banners => _banners;
  List<Product> get featuredProducts => _featuredProducts;
  List<Product> get newArrivals => _newArrivals;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategoryId => _selectedCategoryId;
  String get sortBy => _sortBy;

  // =================== التهيئة والتحميل ===================

  Future<void> initialize() async {
    if (!_firebaseService.isInitialized) {
      await _firebaseService.initialize();
    }
    await loadAll();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadProducts(),
        _loadCategories(),
        _loadBanners(),
      ]);
      _error = null;
    } catch (e) {
      _error = 'فشل تحميل البيانات: $e';
      debugPrint('Error loading data: $e');
      // إذا فشل الاتصال بقاعدة البيانات، استخدم البيانات الافتراضية
      _loadSampleData();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    try {
      final productsData = await _firebaseService.getProducts();
      _products = productsData.map((data) => Product.fromMap(data)).toList();

      _featuredProducts = _products.where((p) => p.isFeatured).toList();
      _newArrivals = _products.where((p) => p.isNewArrival).toList();
    } catch (e) {
      debugPrint('Error loading products from Firebase: $e');
      rethrow;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesData = await _firebaseService.getCategories();
      _categories =
          categoriesData.map((data) => Category.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Error loading categories from Firebase: $e');
      rethrow;
    }
  }

  Future<void> _loadBanners() async {
    try {
      final bannersData = await _firebaseService.getActiveBanners();
      _banners = bannersData.map((data) => BannerModel.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Error loading banners from Firebase: $e');
      rethrow;
    }
  }

  // =================== بيانات تجريبية (عند فشل الاتصال) ===================

  void _loadSampleData() {
    _categories = AppConstants.categories
        .map((data) => Category(
              id: data['id'],
              name: data['name'],
              nameEn: data['nameEn'],
              icon: data['icon'],
            ))
        .toList();

    _products = _generateSampleProducts();
    _featuredProducts = _products.where((p) => p.isFeatured).toList();
    _newArrivals = _products.where((p) => p.isNewArrival).toList();
    _banners = _generateSampleBanners();
  }

  List<Product> _generateSampleProducts() {
    final random = Random();
    return List.generate(40, (index) {
      final isFeatured = index < 6;
      final isNew = index >= 6 && index < 12;
      final hasDiscount = index % 3 == 0;
      final categoryIndex = index % _categories.length;
      final category = _categories[categoryIndex];

      return Product(
        id: 'sample_${index + 1}',
        name: _sampleNames[index % _sampleNames.length],
        description: _sampleDescriptions[index % _sampleDescriptions.length],
        price: 15000.0 + (index * 5000),
        oldPrice: hasDiscount ? 25000.0 + (index * 5000) : null,
        categoryId: category.id,
        categoryName: category.name,
        images: [
          'https://picsum.photos/seed/${index}a/400/500',
          'https://picsum.photos/seed/${index}b/400/500',
          'https://picsum.photos/seed/${index}c/400/500',
        ],
        sizes: ['52', '54', '56', '58', '60'],
        colors: ['أسود', 'كحلي', 'رمادي', 'بيج'],
        colorOptions: [
          {'name': 'أسود', 'hex': '#000000'},
          {'name': 'كحلي', 'hex': '#0D1B3E'},
          {'name': 'رمادي', 'hex': '#808080'},
          {'name': 'بيج', 'hex': '#F5F5DC'},
        ],
        rating: 3.5 + (random.nextDouble() * 1.5),
        reviewCount: random.nextInt(50) + 5,
        isFeatured: isFeatured,
        isNewArrival: isNew,
        hasDiscount: hasDiscount,
        discountPercentage: hasDiscount ? 20 + random.nextInt(30) : 0,
        brand: 'ALAFIF NEWFORM',
        material: index % 2 == 0 ? 'قطن مصري فاخر' : 'صوف إيطالي',
        careInstructions: 'غسيل جاف فقط - كي بدرجة حرارة متوسطة',
      );
    });
  }

  List<BannerModel> _generateSampleBanners() {
    return [
      BannerModel(
        id: 'banner1',
        title: 'المجموعة الشتوية 2026',
        subtitle: 'تصاميم عصرية بأقمشة فاخرة',
        imageUrl: 'https://picsum.photos/seed/banner1/800/400',
        buttonText: 'تسوق الآن',
        order: 1,
      ),
      BannerModel(
        id: 'banner2',
        title: 'خصومات تصل إلى 50%',
        subtitle: 'على تشكيلة الثياب والبذلات',
        imageUrl: 'https://picsum.photos/seed/banner2/800/400',
        buttonText: 'استفد من العرض',
        order: 2,
      ),
      BannerModel(
        id: 'banner3',
        title: 'أزياء العيد',
        subtitle: 'أفخم التصاميم للمناسبات السعيدة',
        imageUrl: 'https://picsum.photos/seed/banner3/800/400',
        buttonText: 'اكتشف المجموعة',
        order: 3,
      ),
    ];
  }

  // =================== الفلترة والفرز ===================

  List<Product> _applyFilters(List<Product> products) {
    var result = List<Product>.from(products);

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
              p.tags.any((tag) => tag.toLowerCase().contains(query)))
          .toList();
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

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = '';
    _sortBy = 'newest';
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

// =================== بيانات تجريبية ===================

const List<String> _sampleNames = [
  'ثوب رجالي فاخر - موديل 2026',
  'بذلة رجالية إيطالية كلاسيك',
  'قميص رجالي بقصة ضيقة',
  'سروال رجالي رسمي',
  'مشمل رجالي فاخر',
  'ثوب رجالي قطني مريح',
  'بذلة زفاف فاخرة',
  'قميص كتان طبيعي',
  'سروال جينز رجالي',
  'ثوب رجالي صيفي',
];

const List<String> _sampleDescriptions = [
  'ثوب رجالي فاخر مصنوع من أفضل أنواع الأقمشة المستوردة. يتميز بقصة عصرية تناسب جميع المناسبات. متوفر بمجموعة واسعة من المقاسات والألوان.',
  'بذلة رجالية كلاسيك بقصة إيطالية أنيقة. مصنوعة من صوف عالي الجودة مع لمسة من الحرير الطبيعي. مناسبة للمناسبات الرسمية وأعمال المكتب.',
  'قميص رجالي عصري بقصة ضيقة (Slim Fit). مصنوع من قماش قطني فاخر يضمن الراحة طوال اليوم. مثالي للإطلالات العصرية.',
  'سروال رجالي رسمي أنيق. مصنوع من أقمشة عالية الجودة مع تقنيات حياكة متطورة. يناسب جميع الإطلالات الرسمية ونصف الرسمية.',
  'مشمل رجالي فاخر من أفخر أنواع الصوف. يتميز بتصميم تقليدي مع لمسات عصرية. مثالي للإطلالات الأنيقة في المناسبات.',
];
