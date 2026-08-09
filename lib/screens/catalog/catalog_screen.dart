import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/skeleton_widget.dart';
import 'product_detail_screen.dart' deferred as detail;

/// شاشة الكتالوج / كافة المنتجات
class CatalogScreen extends StatefulWidget {
  final String? initialCategoryId;

  /// فلتر عرض مسبق: 'new' | 'offers' | 'trends' (من أيقونات الصفحة الرئيسية)
  final String? initialFilter;

  const CatalogScreen({super.key, this.initialCategoryId, this.initialFilter});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _showFilters = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialCategoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProductProvider>().setCategoryFilter(widget.initialCategoryId!);
      });
    }
    // تعيين/مسح فلتر العرض دائماً (يمنع تسرب فلتر سابق عند فتح فئة)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().setDisplayFilter(widget.initialFilter);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// التحميل التلقائي عند الاقتراب من نهاية القائمة
  void _onScroll() {
    final provider = context.read<ProductProvider>();
    if (!provider.hasMore || provider.isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 300) {
      provider.loadMoreProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
            super.build(context);
        return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث عن منتج...',
              prefixIcon: Icon(Icons.search),
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            onChanged: (query) {
              context.read<ProductProvider>().setSearchQuery(query);
            },
          ),
          actions: [
            Consumer<ProductProvider>(
              builder: (context, provider, _) {
                final hasFilters = provider.hasActiveFilters;
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                      ),
                      tooltip: 'فلاتر',
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters),
                    ),
                    if (hasFilters)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: Consumer<ProductProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: () => provider.loadAll(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // =========== فلاتر الفئات ===========
                  SliverToBoxAdapter(
                    child: _buildCategoryChips(provider),
                  ),

                  // =========== لوحة الفلاتر المتقدمة ===========
                  if (_showFilters)
                    SliverToBoxAdapter(
                      child: _buildFilterPanel(provider),
                    ),

                  // =========== شريط الفلاتر النشطة ===========
                  if (provider.hasActiveFilters)
                    SliverToBoxAdapter(
                      child: _buildActiveFilterChips(provider),
                    ),

                  // =========== ترتيب ===========
                  SliverToBoxAdapter(
                    child: _buildSortRow(provider),
                  ),

                  // =========== المحتوى: تحميل / فارغ / شبكة ===========
                  if (provider.isLoading)
                    _buildShimmerGrid()
                  else if (provider.filteredProducts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = provider.filteredProducts[index];
                            return ProductCard(
                              product: product,
                              onTap: () async {
                                await detail.loadLibrary();
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => detail.ProductDetailScreen(
                                      product: product,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: provider.filteredProducts.length,
                          // أداء: لا تُبقي الأطفال أحياء خارج الشاشة، اعزل مناطق الرسم
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                        ),
                      ),
                    ),
                  if (provider.isLoadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// أزرار الفئات الأفقية مع شريحة "الكل"
  Widget _buildCategoryChips(ProductProvider provider) {
    final categories = provider.categories;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          // زر "الكل"
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: FilterChip(
              label: const Text('الكل'),
              selected: provider.selectedCategoryId.isEmpty,
              onSelected: (_) => provider.setCategoryFilter(''),
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                fontFamily: 'NotoKufiArabic',
                fontSize: 13,
                fontWeight:
                    provider.selectedCategoryId.isEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                color:
                    provider.selectedCategoryId.isEmpty
                        ? Colors.white
                        : AppColors.textPrimary,
              ),
              backgroundColor: AppColors.background,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          // فئات المنتجات
          ...categories.map((category) {
            final isSelected = provider.selectedCategoryId == category.id;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                label: Text(category?.name ?? ''),
                selected: isSelected,
                onSelected: (_) {
                  provider.setCategoryFilter(
                    isSelected ? '' : category.id,
                  );
                },
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontFamily: 'NotoKufiArabic',
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                backgroundColor: AppColors.background,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// صف خيار الترتيب
  Widget _buildSortRow(ProductProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text(
            'ترتيب حسب:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: provider.sortBy,
            underline: const SizedBox(),
            style: const TextStyle(
              fontFamily: 'NotoKufiArabic',
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            dropdownColor: Colors.white,
            items: AppConstants.sortOptions.map((option) {
              return DropdownMenuItem(
                value: option['id'] as String,
                child: Text(option['label'] as String),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                provider.setSortBy(value);
              }
            },
          ),
        ],
      ),
    );
  }

  /// شبكة تحميل متألقة (Skeleton) تحتوي على 6 عناصر وهمية
  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ProductCardSkeleton(),
          childCount: 6,
        ),
      ),
    );
  }

  /// حالة عدم وجود منتجات
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 20),
          const Text(
            'لا توجد منتجات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'لم نتمكن من العثور على منتجات\nتطابق معايير البحث المحددة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // =================== الفلاتر المتقدمة ===================

  /// لوحة الفلاتر المتقدمة
  Widget _buildFilterPanel(ProductProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================== نطاق السعر ===================
          _buildFilterSectionLabel('نطاق السعر'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPriceField(
                  hint: 'من',
                  value: provider.minPrice > 0 ? provider.minPrice.toStringAsFixed(0) : '',
                  onChanged: (v) {
                    final min = double.tryParse(v) ?? 0;
                    provider.setPriceRange(min, provider.maxPrice);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('—',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              Expanded(
                child: _buildPriceField(
                  hint: 'إلى',
                  value: provider.maxPrice > 0 ? provider.maxPrice.toStringAsFixed(0) : '',
                  onChanged: (v) {
                    final max = double.tryParse(v) ?? 0;
                    provider.setPriceRange(provider.minPrice, max);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Text(AppConstants.currency,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),

          // =================== المقاسات ===================
          if (provider.availableSizes.isNotEmpty) ...[
            _buildFilterSectionLabel('المقاسات'),
            const SizedBox(height: 8),
            _buildChipRow(
              items: provider.availableSizes.toList()..sort(),
              isSelected: (item) => provider.selectedSizes.contains(item),
              onToggle: (item) => provider.toggleSize(item),
            ),
            const SizedBox(height: 16),
          ],

          // =================== الألوان ===================
          if (provider.availableColors.isNotEmpty) ...[
            _buildFilterSectionLabel('الألوان'),
            const SizedBox(height: 8),
            _buildColorChipRow(provider),
            const SizedBox(height: 16),
          ],

          // =================== الخامات ===================
          if (provider.availableMaterials.isNotEmpty) ...[
            _buildFilterSectionLabel('الخامة'),
            const SizedBox(height: 8),
            _buildChipRow(
              items: provider.availableMaterials.toList()..sort(),
              isSelected: (item) => provider.selectedMaterial == item,
              onToggle: (item) => provider.setMaterial(item),
            ),
            const SizedBox(height: 16),
          ],

          // =================== عروض فقط ===================
          Row(
            children: [
              const Text('العروض والتخفيضات فقط',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textPrimary)),
              const Spacer(),
              SizedBox(
                height: 28,
                child: Switch.adaptive(
                  value: provider.discountOnly,
                  onChanged: (v) => provider.setDiscountOnly(v),
                  activeColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // =================== مسح الكل ===================
          if (provider.hasActiveFilters)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => provider.clearFilters(),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('مسح جميع الفلاتر'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// عنوان قسم في لوحة الفلاتر
  Widget _buildFilterSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// حقل إدخال سعر
  Widget _buildPriceField({
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      style: const TextStyle(fontSize: 14),
      onChanged: onChanged,
    );
  }

  /// صف أفقي من الأزرار (مقاسات، خامات)
  Widget _buildChipRow({
    required List<String> items,
    required bool Function(String) isSelected,
    required ValueChanged<String> onToggle,
  }) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items.map((item) {
          final selected = isSelected(item);
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: FilterChip(
              label: Text(item,
                  style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal)),
              selected: selected,
              onSelected: (_) => onToggle(item),
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              backgroundColor: AppColors.background,
              side: BorderSide(color: AppColors.border.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// صف أفقي من دوائر الألوان
  Widget _buildColorChipRow(ProductProvider provider) {
    final colors = provider.availableColors.toList()..sort();
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: colors.map((hex) {
          final selected = provider.selectedColors.contains(hex);
          final color = _parseHexColor(hex);
          final name = _colorNameFromHex(hex);
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => provider.toggleColor(hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.grey.shade300,
                    width: selected ? 3 : 1.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check,
                        size: 16, color: Colors.white)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// شريط الفلاتر النشطة القابلة للإزالة
  Widget _buildActiveFilterChips(ProductProvider provider) {
    final chips = <Widget>[];

    if (provider.minPrice > 0 || provider.maxPrice > 0) {
      final label = 'السعر: ${provider.minPrice > 0 ? provider.minPrice.toStringAsFixed(0) : '0'} - ${provider.maxPrice > 0 ? provider.maxPrice.toStringAsFixed(0) : '∞'} ${AppConstants.currency}';
      chips.add(_buildDismissibleChip(
          label: label,
          onDismiss: () =>
              provider.setPriceRange(0, 0)));
    }

    for (final size in provider.selectedSizes) {
      chips.add(_buildDismissibleChip(
          label: 'مقاس: $size',
          onDismiss: () => provider.toggleSize(size)));
    }

    for (final hex in provider.selectedColors) {
      chips.add(_buildDismissibleChip(
          label: _colorNameFromHex(hex),
          onDismiss: () => provider.toggleColor(hex)));
    }

    if (provider.selectedMaterial.isNotEmpty) {
      chips.add(_buildDismissibleChip(
          label: 'خامة: ${provider.selectedMaterial}',
          onDismiss: () => provider.setMaterial('')));
    }

    if (provider.discountOnly) {
      chips.add(_buildDismissibleChip(
          label: 'عروض فقط',
          onDismiss: () => provider.setDiscountOnly(false)));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: chips,
        ),
      ),
    );
  }

  /// شريحة فلتر قابلة للإزالة
  Widget _buildDismissibleChip({
    required String label,
    required VoidCallback onDismiss,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Chip(
        label: Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.primary)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDismiss,
        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.only(right: 4),
      ),
    );
  }

  // =================== أدوات الألوان ===================

  /// تحويل hex code إلى Color
  Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  /// الحصول على اسم اللون من الـ hex code
  String _colorNameFromHex(String hex) {
    final normalized = hex.toUpperCase();
    for (final option in AppConstants.colorOptions) {
      if ((option['hex'] as String).toUpperCase() == normalized) {
        return option['name'] as String;
      }
    }
    return hex;
  }
}
