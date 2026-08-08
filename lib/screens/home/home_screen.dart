import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../models/banner.dart';
import '../../providers/product_provider.dart';
import '../../providers/points_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/skeleton_widget.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';
import '../cart/cart_screen.dart';
import '../catalog/product_detail_screen.dart';
import '../catalog/catalog_screen.dart';
import '../catalog/visual_search_screen.dart';
import '../profile/points_screen.dart';

/// الشاشة الرئيسية — متجر متكامل مع العروض والفلاش سيل
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  Timer? _flashTimer;
  Duration _flashTimeRemaining = const Duration(hours: 8, minutes: 45, seconds: 30);

  @override
  void initState() {
    super.initState();
    // متغير للتأكد من أننا نحمّل الصور المسبقة مرة واحدة فقط
    bool _precached = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ===== تحميل متدرّج بعد عرض أول إطار =====
      // 1) استرجاع الكاش المحلي فوراً + مزامنة الفئات/البانرات في الخلفية
      final pp = context.read<ProductProvider>();
      pp.initialize();
      // 2) المزامنة الفورية — أي تغيير من تطبيق الإدارة ينعكس فوراً
      pp.startRealtimeSync();
      // 3) تحميل المنتجات — عيّنات فورية ثم تحديث من Firestore في الخلفية
      pp.loadInitialProducts();
      // 4) تهيئة النقاط عند عرض الرئيسية
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn && auth.userId != null) {
        context.read<PointsProvider>().initialize(auth.userId!);
      }
    });

    // استمع لتغييرات المنتجات لتحميل الصور المسبقة
    context.read<ProductProvider>().addListener(() {
      if (_precached) return;
      final provider = context.read<ProductProvider>();
      if (!provider.isLoading && provider.products.isNotEmpty) {
        _precached = true;
        ProductProvider.precacheProductThumbnails(
          context,
          provider.products,
          max: 10,
        );
      }
    });
    _startFlashCountdown();
  }

  void _startFlashCountdown() {
    _flashTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_flashTimeRemaining.inSeconds > 0) {
        setState(() => _flashTimeRemaining -= const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Consumer2<ProductProvider, PointsProvider>(
          builder: (context, provider, points, _) {
            return RefreshIndicator(
              onRefresh: () => provider.loadAll(),
              child: ListView(
                children: [
                  // =========== 1. شريط البحث ===========
                  _buildSearchHeader(points),

                  // =========== 2. الفئات السريعة ===========
                  _buildQuickCategories(),

                  // =========== 3. الفلاش سيل ===========
                  _buildFlashSale(provider),

                  // =========== 4. بانر رئيسي ===========
                  _buildBannerCarousel(provider),

                  // =========== 5. الأحدث (New Arrivals) ===========
                  if (provider.products.isNotEmpty)
                    _buildNewArrivalsSection(provider),

                  // =========== 6. المميزة (Featured) ===========
                  if (provider.products.isNotEmpty)
                    _buildFeaturedSection(provider),

                  // =========== 7. تحميل المزيد (Infinite Scroll Trigger) ===========
                  if (provider.hasMore && !provider.isLoading)
                    _buildLoadMoreTrigger(provider),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ======================== Header مع البحث والنقاط ========================

  Widget _buildSearchHeader(PointsProvider points) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              // صف الأيقونات العلوي
              Row(
                children: [
                  // النقاط
                  if (points.isLoading == false)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PointsScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, size: 16, color: Colors.yellowAccent),
                            const SizedBox(width: 4),
                            Text(
                              '${points.points}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  // QR Scanner
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                    onPressed: () {},
                    tooltip: 'مسح QR',
                  ),
                  // الإشعارات
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () {},
                    tooltip: 'الإشعارات',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // شريط البحث
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن منتج...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                      onPressed: _pickImageForSearch,
                      tooltip: 'بحث بالصورة',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (query) {
                    context.read<ProductProvider>().setSearchQuery(query);
                    if (query.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CatalogScreen(),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================== البحث بالصورة ========================

  /// فتح اختيار الصورة (كاميرا أو معرض) ثم الانتقال لشاشة البحث بالصورة
  Future<void> _pickImageForSearch() async {
    final picker = ImagePicker();

    // اختيار المصدر: كاميرا أو المعرض
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'البحث بالصورة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _imageSourceButton(
                        icon: Icons.photo_camera_outlined,
                        label: 'كاميرا',
                        onTap: () =>
                            Navigator.pop(sheetContext, ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _imageSourceButton(
                        icon: Icons.photo_library_outlined,
                        label: 'المعرض',
                        onTap: () =>
                            Navigator.pop(sheetContext, ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      final imageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VisualSearchScreen(imageBase64: imageBase64),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الكاميرا/المعرض'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _imageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== الفئات السريعة ========================

  final List<Map<String, dynamic>> _quickCategories = [
    {'icon': Icons.new_releases, 'label': 'جديد', 'id': 'new'},
    {'icon': Icons.local_fire_department, 'label': 'عروض', 'id': 'flash'},
    {'icon': Icons.trending_up, 'label': 'ترند', 'id': 'trends'},
    {'icon': Icons.checkroom, 'label': 'شمزان', 'id': 'shamzan'},
    {'icon': Icons.work, 'label': 'جاكتات', 'id': 'jackets'},
    {'icon': Icons.watch, 'label': 'إكسسوارات', 'id': 'accessories'},
    {'icon': Icons.flash_on, 'label': 'أقوات', 'id': 'aqwat'},
    {'icon': Icons.percent, 'label': 'تخفيضات', 'id': 'discount'},
  ];

  Widget _buildQuickCategories() {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _quickCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final cat = _quickCategories[index];
          return GestureDetector(
            onTap: () {
              if (cat['id'] == 'new' || cat['id'] == 'flash' ||
                  cat['id'] == 'trends' || cat['id'] == 'discount') {
                final provider = context.read<ProductProvider>();
                provider.setSortBy('newest');
                if (cat['id'] == 'discount') provider.setDiscountOnly(true);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HomeScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CatalogScreen(initialCategoryId: cat['id']),
                  ),
                );
              }
            },
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(cat['icon'], color: AppColors.primary, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  cat['label'],
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ======================== الفلاش سيل مع العداد ========================

  Widget _buildFlashSale(ProductProvider provider) {
    final flashProducts = provider.products
        .where((p) => p.hasDiscount)
        .take(10)
        .toList();

    if (flashProducts.isEmpty) return const SizedBox.shrink();

    final hours = _flashTimeRemaining.inHours;
    final minutes = _flashTimeRemaining.inMinutes.remainder(60);
    final seconds = _flashTimeRemaining.inSeconds.remainder(60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // رأس الفلاش سيل مع العداد
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('تخفيضات اليوم',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              // عداد تنازلي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTimeUnit(hours.toString().padLeft(2, '0'), 'س'),
                    const SizedBox(width: 4),
                    _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'د'),
                    const SizedBox(width: 4),
                    _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'ث'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // قائمة منتجات الفلاش سيل
        SizedBox(
          height: 280,
          child: ListView.separated(
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: flashProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final product = flashProducts[index];
              return SizedBox(
                width: 170,
                child: ProductCard(
                  product: product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeUnit(String value, String unit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ======================== Banner Carousel ========================

  Widget _buildBannerCarousel(ProductProvider provider) {
    final banners = provider.banners;

    // حالة التحميل — شيمر
    if (provider.isLoading && banners.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: BannerSkeleton(),
      );
    }

    // لا توجد بانرات حقيقية — اترك المساحة فارغة (لا بينرات افتراضية)
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    // بانرات حقيقية من Firestore — اعرضها
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 180,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 4),
          enlargeCenterPage: true,
          enlargeFactor: 0.2,
          viewportFraction: 0.9,
        ),
        items: banners.map((b) => _buildBannerItem(b)).toList(),
      ),
    );
  }

  Widget _buildBannerItem(BannerModel banner) {
    return Stack(
      children: [
        Container(
          height: 180,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: banner.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AppImage(
                    imageUrl: banner.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    backgroundColor: AppColors.primaryLight,
                  ),
                )
              : null,
        ),
        Positioned(
          right: 20, left: 20, top: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(banner.title,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(banner.subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
            ],
          ),
        ),
        Positioned(
          bottom: 16, right: 20, left: 20,
          child: ElevatedButton(
            onPressed: () {
              if (banner.productId != null) {
                final p = context.read<ProductProvider>().getProductById(banner.productId!);
                if (p != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)));
              } else if (banner.categoryId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogScreen(initialCategoryId: banner.categoryId)));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(banner.buttonText, style: const TextStyle(fontFamily: 'NotoKufiArabic', fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
        if (banner.imageUrl.isNotEmpty)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDynamicBanner(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: Stack(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: AppColors.primaryLight),
            child: product.images.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AppImage(imageUrl: product.images.first, fit: BoxFit.cover, width: double.infinity, height: double.infinity, backgroundColor: AppColors.primaryLight),
                  )
                : null,
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                ),
              ),
            ),
          ),
          Positioned(right: 20, left: 20, bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${product.price.toStringAsFixed(0)} ريال',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================== أحدث المنتجات ========================

  Widget _buildNewArrivalsSection(ProductProvider provider) {
    final items = provider.newArrivals.take(10).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('أحدث الواصل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen())),
                child: const Text('عرض الكل', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SizedBox(
              width: 170,
              child: ProductCard(
                product: items[i],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: items[i]))),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ======================== المنتجات المميزة ========================

  Widget _buildFeaturedSection(ProductProvider provider) {
    final items = provider.featuredProducts.take(10).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('منتجات مميزة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen())),
                child: const Text('عرض الكل', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SizedBox(
              width: 170,
              child: ProductCard(
                product: items[i],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: items[i]))),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ======================== تحميل المزيد (Infinite Scroll) ========================

  Widget _buildLoadMoreTrigger(ProductProvider provider) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.loadMoreProducts();
    });
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
