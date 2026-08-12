import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../models/banner.dart';
import '../../providers/product_provider.dart';
import '../../providers/points_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/skeleton_widget.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dynamic_multi_item_banner.dart';
import '../../widgets/product_card.dart';
import '../cart/cart_screen.dart';
import '../catalog/product_detail_screen.dart';
import '../catalog/catalog_screen.dart';
import '../catalog/visual_search_screen.dart';
import '../profile/points_screen.dart';
import '../../services/voice_search_service.dart';
import 'package:permission_handler/permission_handler.dart';

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
  int _bannerIndex = 0;

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

                  // =========== 2.5 صفقة اليوم ===========
                  _buildDealOfDay(provider),

                  // =========== 2.6 الفئات (أفاتار دائرية مدمجة) ===========
                  _buildCategoryRow(provider),

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

                  // =========== 6.5 العروض والتخفيضات (Offers) ===========
                  if (provider.products.isNotEmpty)
                    _buildOffersSection(provider),

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
                  // الشعار — أسلوب أمازون
                  const Text(
                    'العفيف نيوفورم',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoKufiArabic',
                    ),
                  ),
                  const SizedBox(width: 10),
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
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.mic, color: AppColors.primary),
                          onPressed: _startVoiceSearch,
                          tooltip: 'بحث صوتي',
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                          onPressed: _pickImageForSearch,
                          tooltip: 'بحث بالصورة',
                        ),
                      ],
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
              const SizedBox(height: 10),
              // شريط الموقع — التوصيل إلى [المستخدم]
              _buildLocationBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// شريط الموقع — يعرض اسم المستخدم أو عنوانه من Firestore مباشرة
  Widget _buildLocationBar() {
    final auth = context.read<AuthProvider>();
    final name = auth.user?.fullName.trim();
    final address = auth.user?.address?.trim();
    final label = (name != null && name.isNotEmpty)
        ? name
        : (address != null && address.isNotEmpty ? address : 'موقعك');
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, color: Colors.white, size: 15),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'التوصيل إلى $label 📍',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
      ],
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

  // ======================== البحث الصوتي ========================

  /// فتح البحث الصوتي: إذن الميكروفون → نافذة الاستماع → إرسال النص كبحث
  Future<void> _startVoiceSearch() async {
    // 1) إذن الميكروفون
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('صلاحية الميكروفون مطلوبة للبحث الصوتي'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // 2) تهيئة محرك التعرف الصوتي
    final service = VoiceSearchService();
    final ready = await service.initialize();
    if (!ready || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('التعرف الصوتي غير متوفر على هذا الجهاز'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 3) نافذة الاستماع
    final text = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: _VoiceSearchSheet(service: service),
      ),
    );

    // 4) إرسال النص المعرَّف كبحث
    if (text != null && text.trim().isNotEmpty && mounted) {
      _submitVoiceQuery(text.trim());
    }
  }

  /// إرسال استعلام صوتي — تماماً كما لو كتبه المستخدم يدوياً
  void _submitVoiceQuery(String query) {
    _searchController.text = query;
    context.read<ProductProvider>().setSearchQuery(query);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CatalogScreen()),
    );
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
    {'icon': Icons.local_fire_department, 'label': 'عروض', 'id': 'offers'},
    {'icon': Icons.trending_up, 'label': 'ترند', 'id': 'trends'},
    {'icon': Icons.checkroom, 'label': 'شمزان', 'id': 'shamzan'},
    {'icon': Icons.work, 'label': 'جاكتات', 'id': 'jackets'},
    {'icon': Icons.watch, 'label': 'إكسسوارات', 'id': 'accessories'},
    {'icon': Icons.percent, 'label': 'تخفيضات', 'id': 'discount'},
  ];

  Widget _buildQuickCategories() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _quickCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = _quickCategories[index];
          return GestureDetector(
            onTap: () {
              final id = cat['id'] as String;
              // فلاتر العرض: جديد / عروض / ترند → كتالوج مفلتر
              if (id == 'new' || id == 'offers' || id == 'trends') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CatalogScreen(initialFilter: id),
                  ),
                );
              } else if (id == 'discount') {
                // خصومات: تفعيل فلتر العروض ثم فتح الكتالوج
                final provider = context.read<ProductProvider>();
                provider.setSortBy('newest');
                provider.setDiscountOnly(true);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CatalogScreen()),
                );
              } else {
                // فئة عادية: شمزان / جاكتات / إكسسوارات...
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CatalogScreen(initialCategoryId: id),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat['icon'], color: AppColors.amazonOrange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================== صفقة اليوم (Deal of the Day) ========================

  /// بانر صفقة اليوم — أعلى منتج مخفّض مع عداد تنازلي
  Widget _buildDealOfDay(ProductProvider provider) {
    final deals = provider.products.where((p) => p.hasDiscount).toList()
      ..sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
    if (deals.isEmpty) return const SizedBox.shrink();
    final deal = deals.first;

    final hours = _flashTimeRemaining.inHours;
    final minutes = _flashTimeRemaining.inMinutes.remainder(60);
    final seconds = _flashTimeRemaining.inSeconds.remainder(60);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.amazonOrangeGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // صورة المنتج
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AppImage(
                imageUrl: deal.images.isNotEmpty ? deal.images.first : '',
                width: 90,
                height: 112,
                fit: BoxFit.cover,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'صفقة اليوم 🔥',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deal.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${deal.price.toStringAsFixed(0)} ${AppConstants.currency}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (deal.hasOldPrice) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${deal.oldPrice!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        '-${deal.discountPercentage}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // عداد تنازلي
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ينتهي خلال ',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        _buildTimeUnit(hours.toString().padLeft(2, '0'), 'س'),
                        const SizedBox(width: 4),
                        _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'د'),
                        const SizedBox(width: 4),
                        _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'ث'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(product: deal),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.amazonDark,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('تسوق الآن'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== الفئات (شريط أفقي مدمج) ========================

  /// شريط أفقي مدمج للفئات — أفاتار دائري 64px + الاسم تحته
  Widget _buildCategoryRow(ProductProvider provider) {
    final products = provider.products;
    final cats = provider.categories
        .where((c) => c.isActive)
        .toList()
      ..sort((a, b) {
        final ca = products.where((p) => p.categoryId == a.id).length;
        final cb = products.where((p) => p.categoryId == b.id).length;
        return cb.compareTo(ca);
      });
    if (cats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تسوق حسب الفئة',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CatalogScreen()),
                ),
                child: const Text('عرض الكل', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = cats[index];
              return _buildCategoryAvatar(cat, products);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// أفاتار دائري صغير (64px) — صورة حقيقية للفئة + الاسم تحتها
  Widget _buildCategoryAvatar(Category cat, List<Product> products) {
    // صورة الفئة: imageUrl إن وُجد، وإلا أول صورة منتج تابع للفئة (صور حقيقية)
    final hasOwnImage = cat.imageUrl != null && cat.imageUrl!.isNotEmpty;
    String? productImage;
    if (!hasOwnImage) {
      for (final p in products) {
        if (p.categoryId == cat.id && p.images.isNotEmpty) {
          productImage = p.images.first;
          break;
        }
      }
    }
    final imageUrl = hasOwnImage ? cat.imageUrl : productImage;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CatalogScreen(initialCategoryId: cat.id),
        ),
      ),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            // أفاتار دائري 64px
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1),
                gradient:
                    imageUrl == null ? _categoryGradient(cat.id) : null,
              ),
              child: imageUrl != null
                  ? AppImage(
                      imageUrl: imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      cacheWidth: 128,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              cat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// تدرج لوني ثابت لكل فئة (بديل الصورة عند غيابها)
  LinearGradient _categoryGradient(String catId) {
    const gradients = [
      [Color(0xFF232F3E), Color(0xFF37475A)],
      [Color(0xFFFF9900), Color(0xFFE8890C)],
      [Color(0xFF0D1B3E), Color(0xFF1A2D5E)],
      [Color(0xFF10B981), Color(0xFF0E8F6D)],
    ];
    final idx = catId.hashCode.abs() % gradients.length;
    final g = gradients[idx];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [g[0], g[1]],
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
          height: 340,
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

    // لا توجد بانرات حقيقية — بانرات ديناميكية من أول 10 منتجات (بديل تلقائي)
    final List<Widget> slides;
    if (banners.isNotEmpty) {
      slides = [
        for (var i = 0; i < banners.length; i++)
          DynamicMultiItemBanner(
            banner: banners[i],
            products: provider.products,
            isActive: i == _bannerIndex,
            onTap: () => _openBannerTarget(banners[i], provider),
          ),
      ];
    } else {
      final fallback = provider.products.take(10).toList();
      if (fallback.isEmpty) return const SizedBox.shrink();
      slides = fallback.map((p) => _buildDynamicBanner(p)).toList();
    }

    // حماية المؤشر بعد تغيّر عدد الشرائح
    final safeIndex = _bannerIndex >= slides.length ? 0 : _bannerIndex;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              CarouselSlider(
                options: CarouselOptions(
                  height: 220,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 4),
                  autoPlayAnimationDuration: const Duration(milliseconds: 700),
                  viewportFraction: 1.0,
                  enableInfiniteScroll: slides.length > 1,
                  onPageChanged: (index, _) {
                    if (index != _bannerIndex) {
                      setState(() => _bannerIndex = index);
                    }
                  },
                ),
                items: slides,
              ),
              // مؤشر النقاط — أسفل منتصف الكاروسيل
              Positioned(
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: i == safeIndex ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == safeIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// فتح وجهة البانر: منتج مرتبط أو فئة
  void _openBannerTarget(BannerModel banner, ProductProvider provider) {
    if (banner.productId != null) {
      final p = provider.getProductById(banner.productId!);
      if (p != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
        );
      }
    } else if (banner.categoryId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CatalogScreen(initialCategoryId: banner.categoryId),
        ),
      );
    }
  }

  Widget _buildDynamicBanner(Product product) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: Stack(
        children: [
          Container(
            height: 220,
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
          height: 340,
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
          height: 340,
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

  // ======================== العروض والتخفيضات ========================

  Widget _buildOffersSection(ProductProvider provider) {
    final items = provider.offerProducts.take(10).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('عروض وتخفيضات',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CatalogScreen())),
                child: const Text('عرض الكل', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 340,
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
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ProductDetailScreen(product: items[i]))),
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

/// نافذة الاستماع الصوتي السفلية — ميكروفون نابض + النص الحي + أزرار تم/إلغاء
class _VoiceSearchSheet extends StatefulWidget {
  final VoiceSearchService service;

  const _VoiceSearchSheet({required this.service});

  @override
  State<_VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<_VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  String _recognizedText = '';
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // بدء الاستماع فور فتح النافذة
    widget.service.startListening(onResult: (words, isFinal) {
      if (!mounted) return;
      setState(() => _recognizedText = words);
      // إغلاق تلقائي عند اكتمال التعرف
      if (isFinal && words.trim().isNotEmpty) {
        _finish(words.trim());
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.service.cancel();
    super.dispose();
  }

  Future<void> _finish(String text) async {
    if (!mounted) return;
    await widget.service.stop();
    Navigator.of(context).pop(text);
  }

  void _cancel() {
    widget.service.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مؤشر نبض الميكروفون
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.18).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'تحدث الآن...',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            // النص المعرَّف حتى اللحظة
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _recognizedText.isEmpty ? '...' : _recognizedText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _recognizedText.trim().isEmpty
                        ? null
                        : () => _finish(_recognizedText.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('تم'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
