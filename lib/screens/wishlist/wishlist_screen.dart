import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../providers/product_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/product_card.dart';
import '../catalog/product_detail_screen.dart';

/// شاشة المفضلة (قائمة الرغبات)
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المفضلة'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            Consumer<WishlistProvider>(
              builder: (context, wishlist, _) {
                if (wishlist.count > 0) {
                  return IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: 'مسح الكل',
                    onPressed: () => _confirmClearAll(context, wishlist),
                  );
                }
                return const SizedBox();
              },
            ),
          ],
        ),
        body: Consumer2<WishlistProvider, ProductProvider>(
          builder: (context, wishlist, products, _) {
            if (wishlist.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final wishlistProducts = wishlist.getWishlistProducts(products.products);

            if (wishlistProducts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'المفضلة فارغة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أضف المنتجات التي تعجبك إلى المفضلة',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.shopping_bag),
                      label: const Text('تصفح المنتجات'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => wishlist.loadWishlist(),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: wishlistProducts.length,
                itemBuilder: (context, index) {
                  final product = wishlistProducts[index];
                  return ProductCard(
                    product: product,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WishlistProvider wishlist) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مسح المفضلة'),
          content: const Text('هل أنت متأكد من مسح جميع المنتجات من المفضلة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('تراجع'),
            ),
            TextButton(
              onPressed: () {
                wishlist.clearWishlist();
                Navigator.of(ctx).pop();
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('مسح الكل'),
            ),
          ],
        ),
      ),
    );
  }
}
