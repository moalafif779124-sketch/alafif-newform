import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/stylist_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/skeleton_widget.dart';

/// المصمم الذكي — إطلالة كاملة بالذكاء الاصطناعي (DeepSeek)
class AiStylistScreen extends StatefulWidget {
  const AiStylistScreen({super.key});

  @override
  State<AiStylistScreen> createState() => _AiStylistScreenState();
}

class _AiStylistScreenState extends State<AiStylistScreen> {
  // ===== تفضيلات المستخدم =====
  String _occasion = 'يومي';
  String _style = 'كاجوال';
  String? _size;
  double _budget = 50000;

  // ===== حالة الشاشة =====
  bool _loading = false;
  String? _error;
  StylistOutfit? _outfit;

  static const List<String> _occasions = [
    'يومي',
    'عمل / مكتب',
    'مناسبة / عرس',
    'عيد',
    'سفر',
    'جامعة',
  ];

  static const List<String> _styles = [
    'كاجوال',
    'رسمي',
    'أنيق / سمارت كاجوال',
    'تقليدي',
    'شتوي',
  ];

  @override
  void initState() {
    super.initState();
    // مقاس افتراضي من المنتجات المتاحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductProvider>();
      final sizes = <String>{};
      for (final p in provider.products) {
        sizes.addAll(p.sizes);
      }
      final sorted = sizes.toList()
        ..sort((a, b) {
          final na = int.tryParse(a);
          final nb = int.tryParse(b);
          if (na != null && nb != null) return na.compareTo(nb);
          if (na != null) return -1;
          if (nb != null) return 1;
          return a.compareTo(b);
        });
      if (mounted && sorted.isNotEmpty) {
        setState(() => _size = sorted.contains('L') ? 'L' : sorted.first);
      }
    });
  }

  /// المقاسات المتاحة في المتجر (مرتّبة رقمياً ثم أبجدياً)
  List<String> _availableSizes(ProductProvider provider) {
    final sizes = <String>{};
    for (final p in provider.products) {
      sizes.addAll(p.sizes);
    }
    final list = sizes.toList()
      ..sort((a, b) {
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        if (na != null) return -1;
        if (nb != null) return 1;
        return a.compareTo(b);
      });
    return list;
  }

  /// فلترة المنتجات: متوفرة بالمقاس + نشطة + لها مخزون
  List<Map<String, dynamic>> _filterProducts(ProductProvider provider) {
    final size = _size ?? 'L';
    final result = <Map<String, dynamic>>[];

    for (final p in provider.products) {
      if (!p.isActive) continue;
      // يجب أن يتوفر المقاس المطلوب
      if (p.sizes.isNotEmpty && !p.sizes.contains(size)) continue;
      // تجاهل المنتجات غير المتوفرة (المقاس المختار بنفد)
      final variantStock = p.stockVariants[size];
      if (p.stockVariants.isNotEmpty && variantStock != null && variantStock <= 0) {
        continue;
      }
      if (p.stockVariants.isEmpty && p.stockQuantity <= 0) continue;

      // اللون الأساسي للمنتج
      final colorFamily = _deriveColorFamily(p);
      result.add({
        'id': p.id,
        'name': p.name,
        'price': p.effectivePrice,
        'categoryId': p.categoryId,
        'categoryName': p.categoryName,
        'sizes': p.sizes,
        'tags': p.tags.take(6).toList(),
        'colorFamily': colorFamily,
        'styleType': _deriveStyleType(p),
      });
    }
    return result;
  }

  /// استنتاج عائلة اللون من بيانات المنتج (colorOptions / colors / الاسم)
  String _deriveColorFamily(Product p) {
    final source = [
      ...p.colorOptions.map((c) => c['name'] ?? ''),
      ...p.colors,
      p.name,
    ].join(' ').toLowerCase();

    const map = {
      'أبيض': 'white', 'ابيض': 'white', 'white': 'white',
      'أسود': 'black', 'اسود': 'black', 'black': 'black',
      'كحلي': 'navy', 'navy': 'navy', 'أزرق': 'navy', 'ازرق': 'navy', 'blue': 'navy',
      'بيج': 'beige', 'beige': 'beige', 'كريمي': 'beige', 'جملي': 'brown',
      'رمادي': 'grey', 'رمادى': 'grey', 'grey': 'grey', 'gray': 'grey',
      'بني': 'brown', 'brown': 'brown', 'جلد': 'brown',
      'أخضر': 'green', 'اخضر': 'green', 'green': 'green',
      'أحمر': 'red', 'احمر': 'red', 'red': 'red',
      'زيتي': 'olive', 'olive': 'olive',
    };
    for (final entry in map.entries) {
      if (source.contains(entry.key)) return entry.value;
    }
    return '';
  }

  /// استنتاج نمط المنتج من الفئة والأعلام
  String _deriveStyleType(Product p) {
    if (p.categoryId == 'shamzan' || p.categoryId == 'suits' || p.categoryId == 'belts') {
      return 'formal';
    }
    if (p.isWinterCollection) return 'winter';
    if (p.categoryId == 'jackets') return 'smart_casual';
    if (p.categoryId == 'pajamas' || p.categoryId == 'underwear') return 'casual';
    return 'casual';
  }

  /// توليد الإطلالة من الخادم
  Future<void> _generate() async {
    if (_size == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المقاس أولاً'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final provider = context.read<ProductProvider>();
    final products = _filterProducts(provider);

    if (products.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد منتجات كافية متوفرة بالمقاس المطلوب'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _outfit = null;
    });

    try {
      final outfit = await StylistService.generateOutfit(
        preferences: StylistPreferences(
          occasion: _occasion,
          style: _style,
          budget: _budget,
          size: _size!,
        ),
        filteredProducts: products,
      );
      debugPrint(
        '🎨 Stylist returned ${outfit.selectedProducts.length} piece(s) '
        'for ${products.length} candidates: '
        '${outfit.selectedProducts.map((p) => '${p.productId}/${p.size}').join(', ')}',
      );
      if (!mounted) return;
      setState(() {
        _outfit = outfit;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر توليد الإطلالة. تأكد من الاتصال وحاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  /// إضافة الإطلالة كاملة إلى السلة
  Future<void> _addOutfitToCart() async {
    final outfit = _outfit;
    if (outfit == null) return;

    final productProvider = context.read<ProductProvider>();
    final cart = context.read<CartProvider>();
    final batch = <CartItem>[];
    final missing = <String>[];

    for (final pick in outfit.selectedProducts) {
      final Product? product = productProvider.getProductById(pick.productId);
      if (product == null) {
        missing.add(pick.productId);
        debugPrint('⚠️ Stylist piece not found in catalogue: ${pick.productId}');
        continue;
      }

      // ===== ضبط المقاس: يجب أن يكون مقاساً فعلياً متاحاً للمنتج =====
      final requested = _size ?? '';
      String size = pick.size;
      if (product.sizes.isEmpty) {
        // منتج بلا قائمة مقاسات — لا يمكن التحقق، فنستخدم مقاس المستخدم
        size = requested.isNotEmpty ? requested : pick.size;
      } else if (!product.sizes.contains(size)) {
        // مقاس الذكاء الاصطناعي غير متاح → نجرّب مقاس المستخدم
        if (product.sizes.contains(requested)) {
          size = requested;
        } else {
          // لا المقاس المطلوب ولا مقاس الذكاء الاصطناعي متاح → تخطَّ القطعة
          debugPrint('⚠️ Skipping ${product.name}: no valid size (ai=$pick.size, user=$requested)');
          missing.add(pick.productId);
          continue;
        }
      }

      final colorName = product.colorOptions.isNotEmpty
          ? (product.colorOptions.first['name'] ?? '')
          : (product.colors.isNotEmpty ? product.colors.first : '');
      final colorHex = product.colorOptions.isNotEmpty
          ? (product.colorOptions.first['hex'] ?? '#000000')
          : '#000000';

      batch.add(
        CartItem(
          id: '${product.id}_${size}_stylist_${DateTime.now().millisecondsSinceEpoch}',
          product: product,
          size: size,
          color: colorName,
          colorHex: colorHex,
          quantity: 1,
        ),
      );
    }

    // ===== إضافة واحدة مجمّعة: كتابة محلية + مزامنة سحابية + إشعار مرة واحدة =====
    final added = batch.length;
    cart.addItems(batch);

    debugPrint('🛒 Stylist add-to-cart: $added added, ${missing.length} skipped');
    if (!mounted) return;

    final skippedNote = missing.isNotEmpty ? ' (تعذّرت ${missing.length} قطعة)' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              added > 0 ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                added > 0
                    ? 'تمت إضافة $added قطعة إلى السلة ✓$skippedNote'
                    : 'تعذّرت الإضافة — المنتجات غير متوفرة',
              ),
            ),
          ],
        ),
        backgroundColor: added > 0 ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مصمم الأزياء الذكي ✨'),
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 18),
            _buildPreferencesCard(provider),
            const SizedBox(height: 16),
            _buildGenerateButton(),
            const SizedBox(height: 20),

            if (_loading) ...[
              const _StylistLoadingSkeleton(),
            ] else if (_error != null) ...[
              _buildErrorCard(_error!),
            ] else if (_outfit != null) ...[
              _buildOutfitResult(_outfit!),
            ] else ...[
              _buildEmptyHint(),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ==================== Hero ====================

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إطلالتك جاهزة في ثوانٍ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اختر المناسبة والمقاس والميزانية — وسننسّق لك إطلالة كاملة من منتجاتنا المتوفرة.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== التفضيلات ====================

  Widget _buildPreferencesCard(ProductProvider provider) {
    final sizes = _availableSizes(provider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفضيلاتك',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // المناسبة
          _label('المناسبة'),
          DropdownButtonFormField<String>(
            value: _occasion,
            decoration: _inputDecoration(),
            items: _occasions
                .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 14))))
                .toList(),
            onChanged: (v) => setState(() => _occasion = v ?? _occasion),
          ),
          const SizedBox(height: 14),

          // النمط
          _label('النمط المفضل'),
          DropdownButtonFormField<String>(
            value: _style,
            decoration: _inputDecoration(),
            items: _styles
                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14))))
                .toList(),
            onChanged: (v) => setState(() => _style = v ?? _style),
          ),
          const SizedBox(height: 14),

          // المقاس
          _label('المقاس'),
          if (sizes.isEmpty)
            const Text('جارِ تحميل المقاسات…', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
          else
            DropdownButtonFormField<String>(
              value: (_size != null && sizes.contains(_size)) ? _size : sizes.first,
              decoration: _inputDecoration(),
              items: sizes
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (v) => setState(() => _size = v),
            ),
          const SizedBox(height: 14),

          // الميزانية
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('الميزانية'),
              Text(
                '${_budget.toStringAsFixed(0)} ريال',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _budget,
            min: 10000,
            max: 300000,
            divisions: 29,
            activeColor: AppColors.primary,
            label: '${_budget.toStringAsFixed(0)} ريال',
            onChanged: (v) => setState(() => _budget = v),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  InputDecoration _inputDecoration() => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppColors.accentLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  // ==================== زر التوليد ====================

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _generate,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome, size: 20),
        label: Text(
          _loading ? 'جارِ تنسيق إطلالتك…' : 'أنشئ إطلالتي ✨',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ==================== نتائج ====================

  Widget _buildEmptyHint() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.checkroom, size: 44, color: AppColors.textSecondary),
          SizedBox(height: 10),
          Text(
            'اضبط تفضيلاتك ثم اضغط «أنشئ إطلالتي»',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitResult(StylistOutfit outfit) {
    final provider = context.read<ProductProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // العنوان + السبب
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      outfit.outfitTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                outfit.stylistReasoning,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'قطع الإطلالة',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        ...outfit.selectedProducts.map((pick) {
          final product = provider.getProductById(pick.productId);
          return _buildPieceCard(pick, product);
        }),

        const SizedBox(height: 12),

        // الإجمالي
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إجمالي الإطلالة',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '${outfit.totalPrice.toStringAsFixed(0)} ريال',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // إضافة الكل للسلة
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _addOutfitToCart,
            icon: const Icon(Icons.add_shopping_cart, size: 20),
            label: const Text(
              'أضف الإطلالة كاملة إلى السلة',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amazonBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieceCard(StylistPick pick, Product? product) {
    final name = product?.name ?? 'منتج';
    final image = (product != null && product.images.isNotEmpty) ? product.images.first : '';
    final price = product?.effectivePrice ?? pick.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: image.isNotEmpty
                ? AppImage(
                    imageUrl: image,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    backgroundColor: AppColors.accentLight,
                  )
                : Container(
                    width: 68,
                    height: 68,
                    color: AppColors.accentLight,
                    child: const Icon(Icons.checkroom, color: AppColors.textSecondary),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'المقاس ${pick.size}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${price.toStringAsFixed(0)} ريال',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (product == null)
            const Icon(Icons.error_outline, color: AppColors.warning, size: 20),
        ],
      ),
    );
  }
}

/// هيكل تحميل (Shimmer) أثناء انتظار المصمم الذكي
class _StylistLoadingSkeleton extends StatelessWidget {
  const _StylistLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  SkeletonWidget(width: 160, height: 16),
                ],
              ),
              SizedBox(height: 14),
              SkeletonWidget(width: double.infinity, height: 12),
              SizedBox(height: 8),
              SkeletonWidget(width: double.infinity, height: 12),
              SizedBox(height: 8),
              SkeletonWidget(width: 200, height: 12),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                SkeletonWidget(width: 68, height: 68, borderRadius: 10),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonWidget(width: double.infinity, height: 13),
                      SizedBox(height: 8),
                      SkeletonWidget(width: 120, height: 13),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
