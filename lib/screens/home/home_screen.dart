import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../models/banner.dart';
import '../../providers/product_provider.dart';
import '../cart/cart_screen.dart';
import '../catalog/product_detail_screen.dart';

/// الشاشة الرئيسية للتطبيق
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // تحميل البيانات عند بدء التشغيل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ألافيف نيوفورم'),
          actions: [
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
            ),
          ],
        ),
        body: Consumer<ProductProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: () => provider.loadAll(),
              child: ListView(
                children: [
                  // =========== 1. Banner Carousel ===========
                  _buildBannerCarousel(provider),

                  // =========== 2. Categories Section ===========
                  _buildCategoriesSection(provider),

                  // =========== 3. New Arrivals Section ===========
                  _buildNewArrivalsSection(provider),

                  // =========== 4. Featured Section ===========
                  _buildFeaturedSection(provider),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ======================== Banner Carousel ========================

  Widget _buildBannerCarousel(ProductProvider provider) {
    final banners = provider.banners;

    if (banners.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        color: AppColors.primaryLight,
        child: const Center(
          child: Text(
            'ألافيف نيوفورم',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return CarouselSlider(
      options: CarouselOptions(
        height: 200,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 4),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        enlargeCenterPage: true,
        enlargeFactor: 0.2,
        viewportFraction: 0.9,
        enableInfiniteScroll: banners.length > 1,
      ),
      items: banners.map((banner) => _buildBannerItem(banner)).toList(),
    );
  }

  Widget _buildBannerItem(BannerModel banner) {
    return Stack(
      children: [
        // خلفية البنر مع تدرج لوني
        Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
              ],
            ),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: banner.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildShimmerPlaceholder(),
                    errorWidget: (_, __, ___) => const SizedBox(),
                  ),
                )
              : null,
        ),

        // النص فوق البنر
        Positioned(
          right: 20,
          left: 20,
          top: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                banner.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                banner.subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // زر البنر
        Positioned(
          bottom: 16,
          right: 20,
          left: 20,
          child: ElevatedButton(
            onPressed: () {
              // التنقل حسب الـ banner
              if (banner.productId != null) {
                final product = context.read<ProductProvider>().getProductById(banner.productId!);
                if (product != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              banner.buttonText,
              style: const TextStyle(
                fontFamily: 'NotoKufiArabic',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // طبقة شفافة فوق الصورة لتحسين قراءة النص
        if (banner.imageUrl.isNotEmpty)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ======================== Categories Section ========================

  Widget _buildCategoriesSection(ProductProvider provider) {
    final categories = provider.categories;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'فئات المنتجات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // التنقل إلى شاشة كل الفئات
                  },
                  child: const Text(
                    'المزيد',
                    style: TextStyle(
                      fontFamily: 'NotoKufiArabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // قائمة الفئات الأفقية
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = provider.selectedCategoryId == category.id;
                return FilterChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    provider.setCategoryFilter(
                      selected ? category.id : '',
                    );
                    if (selected) {
                      // التنقل إلى شاشة الكتالوج مع الفئة المحددة
                      // يمكن إضافة Navigator.push هنا لاحقاً
                    }
                  },
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    fontFamily: 'NotoKufiArabic',
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ======================== New Arrivals Section ========================

  Widget _buildNewArrivalsSection(ProductProvider provider) {
    final newArrivals = provider.newArrivals.take(10).toList();

    if (newArrivals.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'أحدث الواصل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // قائمة المنتجات الأفقية
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: newArrivals.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 180,
                    child: ProductCard(
                      product: newArrivals[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: newArrivals[index],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ======================== Featured Section ========================

  Widget _buildFeaturedSection(ProductProvider provider) {
    final featuredProducts = provider.featuredProducts;

    if (featuredProducts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'المجموعات المميزة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // قائمة المنتجات الأفقية
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: featuredProducts.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 180,
                    child: ProductCard(
                      product: featuredProducts[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: featuredProducts[index],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ======================== Helper Widgets ========================

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        color: Colors.white,
      ),
    );
  }
}

/// بطاقة عرض المنتج (مصغرة)
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.images.first,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppColors.accentLight,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.accentLight,
                              child: const Icon(
                                Icons.image_outlined,
                                color: AppColors.accentDark,
                                size: 40,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.accentLight,
                            child: const Icon(
                              Icons.image_outlined,
                              color: AppColors.accentDark,
                              size: 40,
                            ),
                          ),

                    // شارة الخصم
                    if (product.hasDiscount)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.discount,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${product.discountPercentage}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    // شارة الواصل حديثاً
                    if (product.isNewArrival)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'جديد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // تفاصيل المنتج
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المنتج
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // السعر
                  Row(
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ${AppConstants.currency}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (product.hasOldPrice) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${product.oldPrice!.toStringAsFixed(0)} ${AppConstants.currency}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // التقييم
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 14,
                        color: AppColors.rating,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${product.reviewCount})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
