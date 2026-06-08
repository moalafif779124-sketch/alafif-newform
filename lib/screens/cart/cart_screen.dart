import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../providers/cart_provider.dart';
import '../../models/cart_item.dart';
import '../shell_screen.dart';
import '../checkout/checkout_screen.dart';

/// شاشة سلة التسوق
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سلة التسوق'),
          actions: [
            Consumer<CartProvider>(
              builder: (context, cart, _) {
                if (!cart.hasItems) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () => _confirmClearCart(cart),
                  child: const Text(
                    'تفريغ',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer<CartProvider>(
          builder: (context, cart, _) {
            if (cart.items.isEmpty) {
              return _buildEmptyState();
            }
            return _buildCartContent(cart);
          },
        ),
      ),
    );
  }

  /// إظهار حوار تأكيد تفريغ السلة
  void _confirmClearCart(CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفريغ السلة'),
        content: const Text('هل أنت متأكد من حذف جميع المنتجات من سلة التسوق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(ctx);
            },
            child: const Text(
              'تأكيد',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// حالة السلة الفارغة
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: AppColors.accent,
            ),
            const SizedBox(height: 20),
            const Text(
              'سلتك فارغة',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'تصفح منتجاتنا وأضف ما تفضله',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const MainShell(),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.store_outlined),
              label: const Text(
                'تصفح المنتجات',
                style: TextStyle(
                  fontFamily: 'NotoKufiArabic',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// محتوى السلة عند وجود منتجات
  Widget _buildCartContent(CartProvider cart) {
    return Column(
      children: [
        // قائمة المنتجات
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              return _buildCartItemCard(cart.items[index], cart);
            },
          ),
        ),
        // إجمالي السلة
        _buildTotalSection(cart),
      ],
    );
  }

  /// بطاقة عنصر واحد في السلة
  Widget _buildCartItemCard(CartItem item, CartProvider cart) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // صورة المنتج
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 100,
                child: item.product.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.product.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.background,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.background,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.accent,
                            size: 32,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.background,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppColors.accent,
                          size: 32,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // الاسم والمقاس واللون والسعر
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.size.isNotEmpty || item.color.isNotEmpty)
                    Text(
                      '${item.size.isNotEmpty ? 'مقاس: ${item.size}' : ''}'
                      '${item.size.isNotEmpty && item.color.isNotEmpty ? ' | ' : ''}'
                      '${item.color.isNotEmpty ? 'لون: ${item.color}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.product.price.toStringAsFixed(0)} ${AppConstants.currency}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // أزرار التحكم بالكمية والحذف
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                  iconSize: 26,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    cart.updateQuantity(item.id, item.quantity + 1);
                  },
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.textSecondary,
                  iconSize: 26,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    cart.updateQuantity(item.id, item.quantity - 1);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  iconSize: 22,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    cart.removeItem(item.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// قسم الإجمالي في أسفل الشاشة
  Widget _buildTotalSection(CartProvider cart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPriceRow(
              'المجموع الفرعي',
              '${cart.subtotal.toStringAsFixed(0)} ${AppConstants.currency}',
            ),
            const SizedBox(height: 8),
            _buildPriceRow(
              'الشحن',
              cart.subtotal >= 50000
                  ? 'مجاني'
                  : '${cart.shipping.toStringAsFixed(0)} ${AppConstants.currency}',
            ),
            const SizedBox(height: 8),
            _buildPriceRow(
              'الضريبة (5%)',
              '${cart.tax.toStringAsFixed(0)} ${AppConstants.currency}',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppColors.border, height: 1),
            ),
            _buildPriceRow(
              'الإجمالي',
              '${cart.total.toStringAsFixed(0)} ${AppConstants.currency}',
              isTotal: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // التنقل إلى شاشة الدفع
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CheckoutScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'متابعة الدفع',
                  style: TextStyle(
                    fontFamily: 'NotoKufiArabic',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// صف سعر واحد (تسمية + قيمة)
  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
