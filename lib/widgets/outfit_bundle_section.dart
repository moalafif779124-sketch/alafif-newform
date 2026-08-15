import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import 'app_image.dart';

/// نسبة خصم الطقم (خصم إضافي عند شراء الإطلالة كاملة)
const double _bundleDiscountRate = 0.10; // 10%

/// قسم "صمم إطلالتك الكاملة" — عناصر مكمّلة مقترحة مع خصم الطقم
class OutfitBundleSection extends StatefulWidget {
  final Product product;

  const OutfitBundleSection({super.key, required this.product});

  @override
  State<OutfitBundleSection> createState() => _OutfitBundleSectionState();
}

class _OutfitBundleSectionState extends State<OutfitBundleSection> {
  late final List<BundleItem> _items;
  final Map<String, String> _selectedSizes = {}; // productId -> size

  @override
  void initState() {
    super.initState();
    _items = _buildBundleItems();
    // المقاس الافتراضي لكل عنصر
    for (final item in _items) {
      final sizes = item.product.sizes;
      if (sizes.isNotEmpty) {
        _selectedSizes[item.product.id] = sizes.first;
      }
    }
  }

  // ======================= منطق الاقتراح الذكي =======================

  List<BundleItem> _buildBundleItems() {
    final all = context.read<ProductProvider>().products;
    final catName = widget.product.categoryName.toLowerCase();
    final catId = widget.product.categoryId.toLowerCase();

    // فئات مستهدفة حسب نوع المنتج الحالي
    List<String> targetCategoryIds = [];

    // رسمي/بدلات → قمصان (شمزان) + حزامات
    final isFormal = catName.contains('بدلات') ||
        catName.contains('بذل') ||
        catName.contains('ثياب') ||
        catName.contains('ثوب') ||
        catId.contains('badlat') ||
        catId.contains('suit') ||
        catId.contains('thob');
    if (isFormal) {
      targetCategoryIds = ['shamzan', 'belts'];
    }
    // كاجوال/شمزان → بنطلونات أو جاكتات
    else if (catId.contains('shamzan') || catName.contains('شمزان')) {
      targetCategoryIds = ['aZ1VDCIdr7OO7mGSPHjj', 'jackets']; // بنطلونات، جاكتات
    }
    // فنايل/قمصان → جاكتات أو شمزان
    else if (catId.contains('fanail') || catName.contains('فنايل') || catName.contains('فانيل')) {
      targetCategoryIds = ['jackets', 'shamzan'];
    }

    final picked = <Product>[];
    // 1) من الفئات المستهدفة
    for (final id in targetCategoryIds) {
      for (final p in all) {
        if (p.id == widget.product.id) continue;
        if (!p.isActive) continue;
        if (p.categoryId == id && p.images.isNotEmpty) {
          picked.add(p);
        }
        if (picked.length >= 3) break;
      }
      if (picked.length >= 3) break;
    }
    // 2) بديل: أعلى تقييماً من فئات أخرى (غير فئة المنتج الحالي)
    if (picked.length < 2) {
      final others = all
          .where((p) =>
              p.id != widget.product.id &&
              p.isActive &&
              p.categoryId != widget.product.categoryId &&
              p.images.isNotEmpty)
          .toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
      for (final p in others) {
        picked.add(p);
        if (picked.length >= 3) break;
      }
    }

    // حوّل إلى عناصر طقم مع تحديد افتراضي
    return picked.take(3).map((p) => BundleItem(product: p)).toList();
  }

  // ======================= الحسابات =======================

  double get _originalTotal =>
      _items.where((i) => i.selected).fold(0.0, (s, i) => s + i.product.price);

  double get _discountedTotal => _originalTotal * (1 - _bundleDiscountRate);

  double get _savings => _originalTotal - _discountedTotal;

  int get _selectedCount => _items.where((i) => i.selected).length;

  // ======================= إضافة للسلة =======================

  void _addBundleToCart(BuildContext context) {
    final cart = context.read<CartProvider>();
    final selected = _items.where((i) => i.selected).toList();
    if (selected.isEmpty) return;

    for (final item in selected) {
      cart.addItem(CartItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${item.product.id}',
        product: item.product,
        size: _selectedSizes[item.product.id] ?? '',
        color: '',
        quantity: 1,
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تمت إضافة الإطلالة كاملة (${selected.length} منتجات) إلى السلة ✅',
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ======================= الواجهة =======================

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.amazonNavy.withValues(alpha: 0.06),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amazonNavy.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== العنوان =====
          const Row(
            children: [
              Text(
                '✨ صمم إطلالتك الكاملة',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'اشترِ الطقم كاملاً ووفّر المزيد',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),

          // ===== عناصر الطقم =====
          ..._items.map((item) => _buildBundleCard(item)),

          const SizedBox(height: 12),

          // ===== بطاقة إجمالي الطقم =====
          _buildBundleTotalCard(),

          const SizedBox(height: 12),

          // ===== زر إضافة الطقم =====
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedCount == 0
                  ? null
                  : () => _addBundleToCart(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amazonYellow,
                foregroundColor: AppColors.amazonDark,
                disabledBackgroundColor: AppColors.accent,
                disabledForegroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(
                'إضافة الإطلالة بالكامل للسلة ($_selectedCount)',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundleCard(BundleItem item) {
    final sizes = item.product.sizes;
    final sizeValue = _selectedSizes[item.product.id] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.selected
              ? AppColors.amazonBlue.withValues(alpha: 0.4)
              : AppColors.border,
          width: item.selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // ===== مربع الاختيار =====
          Checkbox(
            value: item.selected,
            activeColor: AppColors.amazonBlue,
            onChanged: (v) => setState(() => item.selected = v ?? false),
          ),
          // ===== الصورة المصغرة =====
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(
              imageUrl: item.product.images.isNotEmpty
                  ? item.product.images.first
                  : '',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              backgroundColor: AppColors.accentLight,
            ),
          ),
          const SizedBox(width: 10),
          // ===== الاسم + السعر + المقاس =====
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.product.price.toStringAsFixed(0)} ${AppConstants.currency}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (sizes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // قائمة المقاسات
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sizeValue,
                        isDense: true,
                        iconSize: 18,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textPrimary,
                        ),
                        items: sizes.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: item.selected
                            ? (v) {
                                if (v != null) {
                                  setState(
                                      () => _selectedSizes[item.product.id] = v);
                                }
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundleTotalCard() {
    if (_selectedCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'اختر منتجاً واحداً على الأقل لتفعيل خصم الطقم',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.amazonNavy, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الإجمالي الأصلي',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${_originalTotal.toStringAsFixed(0)} ${AppConstants.currency}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سعر الطقم (خصم ${(_bundleDiscountRate * 100).round()}%)',
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
              Text(
                '${_discountedTotal.toStringAsFixed(0)} ${AppConstants.currency}',
                style: const TextStyle(
                  color: AppColors.amazonYellow,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // شارة التوفير
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.amazonYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.amazonYellow.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'وفر ${_savings.toStringAsFixed(0)} ${AppConstants.currency} 🎉',
              style: const TextStyle(
                color: AppColors.amazonYellow,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// عنصر داخل الطقم — مع حالة التحديد
class BundleItem {
  final Product product;
  bool selected;

  BundleItem({required this.product, this.selected = true});
}
