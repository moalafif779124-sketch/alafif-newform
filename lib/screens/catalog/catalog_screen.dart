import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/colors.dart';
import '../../config/constants.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import 'product_detail_screen.dart';

/// شاشة الكتالوج / كافة المنتجات
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  Widget build(BuildContext context) {
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
        ),
        body: Consumer<ProductProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: () => provider.loadAll(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // =========== فلاتر الفئات ===========
                  SliverToBoxAdapter(
                    child: _buildCategoryChips(provider),
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      product: product,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: provider.filteredProducts.length,
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
                label: Text(category.name),
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

  /// شبكة تحميل متألقة (Shimmer) تحتوي على 6 عناصر وهمية
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
          (context, index) => _buildShimmerItem(),
          childCount: 6,
        ),
      ),
    );
  }

  /// عنصر شبكة وهمي (Shimmer Placeholder)
  Widget _buildShimmerItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // مساحة الصورة
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
            ),
            // مساحة النص
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 100,
                      height: 10,
                      color: Colors.white,
                    ),
                    const Spacer(),
                    Container(
                      width: 80,
                      height: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
}
