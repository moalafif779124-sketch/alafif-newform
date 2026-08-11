import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/product.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/wishlist_provider.dart';
import 'app_image.dart';

/// بطاقة عرض المنتج — مع شارات، ألوان، زر إضافة سريع
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool compact;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final imgHeight = compact ? 140.0 : 180.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            // =========== الصورة ===========
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                children: [
                  Hero(
                    tag: 'product_${product.id}',
                    child: AppImage(
                      imageUrl: product.images.isNotEmpty ? product.images.first : '',
                      height: imgHeight,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      backgroundColor: AppColors.accentLight,
                      cacheWidth: 300,
                    ),
                  ),
                  // شارات
                  if (product.hasDiscount)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${product.discountPercentage}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (product.isNewArrival && !compact)
                    Positioned(
                      top: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('جديد', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  // شارة EXPRESS — للمنتجات ذات المخزون الجاهز الكبير
                  if (product.stockQuantity >= 20)
                    Positioned(
                      top: 40, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.amazonOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 11, color: Colors.white),
                            SizedBox(width: 2),
                            Text('EXPRESS', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  // شارة المخزون المحدود
                  if (product.stockQuantity > 0 && product.stockQuantity < 5)
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${product.stockQuantity} متبقي',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  // شارات خيارات العرض (عيد/شتاء/جديد/عرض/كمية محدودة)
                  if (product.activeDisplayBadges.isNotEmpty)
                    Positioned(
                      bottom: 6, left: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final badge in product.activeDisplayBadges.take(2))
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorFromHex(badge.color),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge.label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // زر المفضلة
                  Positioned(
                    top: 6, left: 6,
                    child: Consumer<WishlistProvider>(
                      builder: (context, wishlist, _) {
                        final isFav = wishlist.isWishlisted(product.id);
                        return GestureDetector(
                          onTap: () => wishlist.toggleWishlist(product.id),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: isFav ? Colors.red : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // =========== التفاصيل ===========
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الاسم
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // التقييم — نجوم بأسلوب أمازون
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= product.rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 13,
                          color: i <= product.rating.round()
                              ? AppColors.rating
                              : AppColors.accent,
                        ),
                      const SizedBox(width: 4),
                      if (product.rating > 0)
                        Text('${product.rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      if (product.reviewCount > 0)
                        Text(' (${product.reviewCount})',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      const Spacer(),
                      // شارة الأكثر مبيعاً
                      if (product.reviewCount > 20)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('الأكثر مبيعاً',
                              style: TextStyle(fontSize: 8, color: AppColors.warning, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ألوان المنتج (نقاط)
                  if (product.colorOptions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: product.colorOptions.take(4).map((c) {
                          final hex = c['hex'] ?? '#000000';
                          final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                          return Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  // السعر
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${product.price.toStringAsFixed(0)} ${AppConstants.currency}',
                              style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary,
                              ),
                            ),
                            if (product.hasOldPrice)
                              Text(
                                '${product.oldPrice!.toStringAsFixed(0)} ${AppConstants.currency}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // زر الإضافة — أصفر أمازون بتدرج
                  Consumer<CartProvider>(
                    builder: (context, cart, _) {
                      final inCart = cart.items.any((i) => i.product.id == product.id);
                      return GestureDetector(
                        onTap: inCart
                            ? null
                            : () {
                                cart.addItem(CartItem(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  product: product,
                                  size: product.sizes.isNotEmpty ? product.sizes.first : '',
                                  color: '',
                                  quantity: 1,
                                ));
                              },
                        child: Container(
                          height: compact ? 32 : 38,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: inCart ? null : AppColors.amazonYellowGradient,
                            color: inCart
                                ? AppColors.success.withValues(alpha: 0.08)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: inCart
                                  ? AppColors.success.withValues(alpha: 0.4)
                                  : const Color(0xFFE08E0B),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                inCart ? Icons.check_circle : Icons.add_shopping_cart,
                                size: compact ? 14 : 16,
                                color: inCart ? AppColors.success : AppColors.amazonDark,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                inCart ? 'أضيف للسلة' : 'إضافة للسلة',
                                style: TextStyle(
                                  fontSize: compact ? 11 : 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: inCart ? AppColors.success : AppColors.amazonDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// تحويل لون HEX (#RRGGBB) إلى Color
  Color _colorFromHex(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}
