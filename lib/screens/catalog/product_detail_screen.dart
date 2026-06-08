import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../models/cart_item.dart';
import '../../models/review.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/app_image.dart';
import '../cart/cart_screen.dart';
import '../checkout/checkout_screen.dart';
import '../try_on/ar_try_on_screen.dart';
import 'add_review_screen.dart';

/// شاشة تفاصيل المنتج
class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  String? _selectedSize;
  int _selectedColorIndex = 0;
  int _quantity = 1;
  bool _isDescriptionExpanded = false;
  bool _isFavorite = false;

  Product get product => widget.product;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (product.sizes.isNotEmpty) {
      _selectedSize = product.sizes.first;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double get _totalPrice => product.price * _quantity;
  double get _oldTotalPrice =>
      product.hasOldPrice ? (product.oldPrice! * _quantity) : _totalPrice;

  void _onShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط المنتج'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onToggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'تمت الإضافة إلى المفضلة' : 'تمت الإزالة من المفضلة'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addToCart({bool goToCheckout = false}) {
    if (_selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المقاس'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final colorName = product.colorOptions.isNotEmpty
        ? product.colorOptions[_selectedColorIndex]['name'] ?? ''
        : (product.colors.isNotEmpty ? product.colors[_selectedColorIndex] : '');

    final colorHex = product.colorOptions.isNotEmpty
        ? product.colorOptions[_selectedColorIndex]['hex'] ?? '#000000'
        : '#000000';

    final cartItem = CartItem(
      id: '${product.id}_${_selectedSize}_${_selectedColorIndex}_${DateTime.now().millisecondsSinceEpoch}',
      product: product,
      size: _selectedSize!,
      color: colorName,
      colorHex: colorHex,
      quantity: _quantity,
    );

    context.read<CartProvider>().addItem(cartItem);

    if (goToCheckout) {
      // Buy Now: go directly to checkout
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CheckoutScreen()),
      );
    } else {
      // Normal add to cart: show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('تمت الإضافة إلى السلة ✓')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'السلة',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  void _buyNow() => _addToCart(goToCheckout: true);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            _buildProductDetails(),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // ======================== SliverAppBar ========================

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 350,
      pinned: false,
      floating: false,
      backgroundColor: AppColors.surface,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, size: 18),
          ),
          onPressed: _onShare,
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: _isFavorite ? AppColors.favorite : null,
            ),
          ),
          onPressed: _onToggleFavorite,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // معرض الصور المنزلقة
            PageView.builder(
              controller: _pageController,
              itemCount: product.images.isNotEmpty ? product.images.length : 1,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final imageUrl = product.images.isNotEmpty
                    ? product.images[index]
                    : 'https://picsum.photos/seed/${product.id}/400/500';
                return AppImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  backgroundColor: AppColors.accentLight,
                );
              },
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(24),
        child: _buildPageIndicator(),
      ),
    );
  }

  // ======================== Page Indicator ========================

  Widget _buildPageIndicator() {
    final imageCount = product.images.isNotEmpty ? product.images.length : 1;
    return Container(
      height: 24,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(imageCount, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ======================== تفاصيل المنتج ========================

  Widget _buildProductDetails() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اسم المنتج + أيقونة المفضلة
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _onToggleFavorite,
                  child: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? AppColors.favorite : AppColors.textSecondary,
                    size: 26,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // التقييم
            _buildRatingRow(),
            const SizedBox(height: 12),

            // السعر
            _buildPriceRow(),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, thickness: 1),
            const SizedBox(height: 16),

            // تجربة افتراضية
            _buildTryOnButton(),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, thickness: 1),
            const SizedBox(height: 16),

            // اختيار المقاس
            _buildSizeSelector(),
            const SizedBox(height: 20),

            // اختيار اللون
            _buildColorSelector(),
            const SizedBox(height: 20),
            const Divider(color: AppColors.divider, thickness: 1),
            const SizedBox(height: 16),

            // الوصف
            _buildDescriptionSection(),
            const SizedBox(height: 16),

            // معلومات إضافية
            _buildAdditionalInfo(),
            const SizedBox(height: 16),

            // التقييمات والمراجعات
            _buildReviewsSection(),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, thickness: 1),
            const SizedBox(height: 16),

            // منتجات مشابهة
            _buildRelatedProducts(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ======================== التقييم ========================

  Widget _buildRatingRow() {
    return Row(
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          if (starValue <= product.rating.floor()) {
            return const Icon(Icons.star, size: 18, color: AppColors.rating);
          } else if (starValue - product.rating < 1 && product.rating - starValue + 1 > 0) {
            return const Icon(Icons.star_half, size: 18, color: AppColors.rating);
          } else {
            return const Icon(Icons.star_border, size: 18, color: AppColors.rating);
          }
        }),
        const SizedBox(width: 6),
        Text(
          product.rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${product.reviewCount} تقييم)',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ======================== السعر ========================

  Widget _buildPriceRow() {
    return Row(
      children: [
        Text(
          '${_totalPrice.toStringAsFixed(0)} ${AppConstants.currency}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        if (product.hasOldPrice) ...[
          const SizedBox(width: 10),
          Text(
            '${_oldTotalPrice.toStringAsFixed(0)} ${AppConstants.currency}',
            style: const TextStyle(
              fontSize: 16,
              decoration: TextDecoration.lineThrough,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '-${product.discountPercentage}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ======================== تجربة افتراضية (AR Try-On) ========================

  /// زر التجربة الافتراضية للثياب والمشالح والشماغ
  Widget _buildTryOnButton() {
    // الفئات التي تدعم التجربة الافتراضية
    const tryOnCategories = ['thobes', 'bisht', 'shemagh'];
    final supportsTryOn = tryOnCategories.contains(product.categoryId);

    if (!supportsTryOn) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'تجربة افتراضية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'شاهد المنتج عليك مباشرة باستخدام الكاميرا',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openTryOn,
              icon: const Icon(Icons.camera_alt_rounded, size: 20),
              label: const Text('جربه الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openTryOn() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VirtualTryOnScreen(
          productId: product.id,
          productName: product.name,
          productImage: product.images.isNotEmpty ? product.images.first : null,
          categoryId: product.categoryId,
        ),
      ),
    );
  }

  // ======================== اختيار المقاس ========================

  Widget _buildSizeSelector() {
    if (product.sizes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختيار المقاس',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: product.sizes.map((size) {
            final isSelected = _selectedSize == size;
            return ChoiceChip(
              label: Text(
                size,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.accentLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onSelected: (selected) {
                setState(() => _selectedSize = size);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ======================== اختيار اللون ========================

  Widget _buildColorSelector() {
    if (product.colorOptions.isEmpty && product.colors.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorOptions = product.colorOptions.isNotEmpty
        ? product.colorOptions
        : product.colors.map((c) => {'name': c, 'hex': '#808080'}).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختيار اللون',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: List.generate(colorOptions.length, (index) {
            final color = colorOptions[index];
            final hex = color['hex'] ?? '#808080';
            final name = color['name'] ?? '';
            final isSelected = _selectedColorIndex == index;

            Color parsedColor;
            try {
              parsedColor = Color(int.parse(hex.replaceFirst('#', '0xFF')));
            } catch (_) {
              parsedColor = const Color(0xFF808080);
            }

            return GestureDetector(
              onTap: () {
                setState(() => _selectedColorIndex = index);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: parsedColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: isSelected ? 8 : 3,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  // ======================== الوصف ========================

  Widget _buildDescriptionSection() {
    if (product.description.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الوصف',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isDescriptionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            product.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
          secondChild: Text(
            product.description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            setState(() => _isDescriptionExpanded = !_isDescriptionExpanded);
          },
          child: Text(
            _isDescriptionExpanded ? 'أخف' : 'أقرأ المزيد',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ======================== معلومات إضافية ========================

  Widget _buildAdditionalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'معلومات إضافية',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildInfoRow('المادة', product.material.isNotEmpty ? product.material : 'غير محدد'),
              const Divider(color: AppColors.divider, height: 20),
              _buildInfoRow('العلامة التجارية', product.brand.isNotEmpty ? product.brand : 'ALAFIF NEWFORM'),
              if (product.careInstructions.isNotEmpty) ...[
                const Divider(color: AppColors.divider, height: 20),
                _buildInfoRow('تعليمات العناية', product.careInstructions),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ======================== التقييمات والمراجعات ========================

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان القسم
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.star_rounded, color: AppColors.rating, size: 22),
                SizedBox(width: 6),
                Text(
                  'التقييمات',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _navigateToAddReview,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('أضف تقييم'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // تحميل التقييمات عند ظهور القسم
        Consumer<ReviewProvider>(
          builder: (context, reviewProvider, _) {
            // بدء التحميل أول مرة
            WidgetsBinding.instance.addPostFrameCallback((_) {
              reviewProvider.checkUserReviewed(
                product.id,
                context.read<AuthProvider>().userId ?? '',
              );
              if (reviewProvider.reviews.isEmpty && !reviewProvider.isLoading) {
                reviewProvider.loadReviews(product.id);
              }
            });

            if (reviewProvider.isLoading && reviewProvider.reviews.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (reviewProvider.reviews.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 48,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'لا توجد تقييمات بعد',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _navigateToAddReview,
                      child: const Text(
                        'كن أول من يقيم هذا المنتج',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // ملخص التقييمات
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // متوسط التقييم
                      Column(
                        children: [
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.rating,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < product.rating.floor()
                                    ? Icons.star
                                    : (i < product.rating ? Icons.star_half : Icons.star_border),
                                size: 16,
                                color: AppColors.rating,
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(${product.reviewCount} تقييم)',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // أحدث التقييمات
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: reviewProvider.reviews.take(2).map((review) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildReviewItem(review),
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // قائمة التقييمات
                if (reviewProvider.reviews.length > 2) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _showAllReviews(reviewProvider.reviews),
                    child: const Text(
                      'عرض كل التقييمات',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// عنصر تقييم واحد
  Widget _buildReviewItem(Review review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                review.userName.isNotEmpty ? review.userName[0] : 'م',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                review.userName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < review.rating.floor() ? Icons.star : Icons.star_border,
                  size: 14,
                  color: AppColors.rating,
                );
              }),
            ),
          ],
        ),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// الانتقال إلى شاشة إضافة تقييم
  void _navigateToAddReview() {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تسجيل الدخول أولاً'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReviewScreen(
          productId: product.id,
          productName: product.name,
        ),
      ),
    );
  }

  /// عرض كل التقييمات في حوار
  void _showAllReviews(List<Review> allReviews) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'كل التقييمات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: allReviews.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (_, index) => _buildReviewItem(allReviews[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ======================== منتجات مشابهة ========================

  Widget _buildRelatedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'منتجات مشابهة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Consumer<ProductProvider>(
          builder: (context, provider, _) {
            final relatedProducts = provider.getRelatedProducts(product.id);
            if (relatedProducts.isEmpty) {
              return const SizedBox.shrink();
            }
            return SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: relatedProducts.length,
                itemBuilder: (context, index) {
                  final relatedProduct = relatedProducts[index];
                  return ProductCard(
                    product: relatedProduct,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailScreen(product: relatedProduct),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // ======================== الشريط السفلي ========================

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // عناصر التحكم في الكمية
              Container(
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 20),
                      color: AppColors.textPrimary,
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$_quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      color: AppColors.textPrimary,
                      onPressed: _quantity < 99
                          ? () => setState(() => _quantity++)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // السعر
              Text(
                '${_totalPrice.toStringAsFixed(0)} ${AppConstants.currency}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),

              // Buy Now button
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _buyNow,
                  icon: const Icon(Icons.flash_on, size: 18),
                  label: const Text('شراء'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Add to Cart button
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => _addToCart(),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: const Text('أضف'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
