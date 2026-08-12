import 'package:flutter/material.dart';
import '../../models/banner.dart';
import '../../models/product.dart';
import 'app_image.dart';

/// بانر هيرو متحرك متعدد المنتجات — منتجات عائمة/منزلقة فوق خلفية متدرجة نابضة
///
/// عند تفعيل البانر في الكاروسيل:
/// - المنتج الرئيسي: ينزلق من اليمين
/// - المنتج الثانوي: ينزلق من الأسفل
/// - المنتج الثالث (إكسسوار): يتلاشى + يطفو بحركة متكررة
/// - طبقة النص: تكبير + تلاشي على اليسار
class DynamicMultiItemBanner extends StatefulWidget {
  final BannerModel banner;
  final List<Product> products;
  final bool isActive;
  final VoidCallback? onTap;

  const DynamicMultiItemBanner({
    super.key,
    required this.banner,
    required this.products,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<DynamicMultiItemBanner> createState() => _DynamicMultiItemBannerState();
}

class _DynamicMultiItemBannerState extends State<DynamicMultiItemBanner>
    with TickerProviderStateMixin {
  late final AnimationController _entrance; // دخول العناصر عند التفعيل
  late final AnimationController _float; // طفو متكرر للإكسسوار

  late final Animation<Offset> _item1Offset; // من اليمين
  late final Animation<Offset> _item2Offset; // من الأسفل
  late final Animation<double> _item3Fade;
  late final Animation<double> _floatY;
  late final Animation<double> _textScale;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _item1Offset = Tween<Offset>(
      begin: const Offset(1.6, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _item2Offset = Tween<Offset>(
      begin: const Offset(0, 1.8),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.2, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _item3Fade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.9, curve: Curves.easeIn),
    );

    _floatY = Tween<double>(begin: -7, end: 7).animate(_float);

    _textScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.35),
    );

    if (widget.isActive) {
      _entrance.forward();
    }
  }

  @override
  void didUpdateWidget(DynamicMultiItemBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // أعد تشغيل حركة الدخول كلما أصبح البانر هو النشط
    if (widget.isActive && !oldWidget.isActive) {
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _float.dispose();
    super.dispose();
  }

  /// اختيار منتجات العرض: مرتبط بالبانر → من نفس الفئة → المميزة → أي منتجات
  List<Product> _pickProducts() {
    final withImages =
        widget.products.where((p) => p.images.isNotEmpty).toList();
    final result = <Product>[];
    void addUnique(Product p) {
      if (!result.any((e) => e.id == p.id)) result.add(p);
    }

    if (widget.banner.productId != null) {
      for (final p in withImages) {
        if (p.id == widget.banner.productId) {
          addUnique(p);
          break;
        }
      }
    }
    if (widget.banner.categoryId != null) {
      for (final p in withImages) {
        if (p.categoryId == widget.banner.categoryId) {
          addUnique(p);
          if (result.length >= 3) return result;
        }
      }
    }
    for (final p in withImages) {
      if (p.isFeatured) {
        addUnique(p);
        if (result.length >= 3) return result;
      }
    }
    for (final p in withImages) {
      addUnique(p);
      if (result.length >= 3) return result;
    }
    return result;
  }

  Widget _productCard(Product p, double w, double h) {
    return Container(
      width: w,
      height: h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AppImage(
        imageUrl: p.images.isNotEmpty ? p.images.first : '',
        width: w,
        height: h,
        fit: BoxFit.cover,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _background() {
    final hasImg = widget.banner.imageUrl.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF232F3E), // كحلي داكن (ALAFIF)
            Color(0xFF0D1B3E),
            Color(0xFF1A2D5E),
          ],
        ),
      ),
      child: hasImg
          ? Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: 0.5,
                  child: AppImage(
                    imageUrl: widget.banner.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x990D1B3E)],
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _pickProducts();
    final title = widget.banner.title.isNotEmpty
        ? widget.banner.title
        : 'خصومات كبرى';
    final subtitle = widget.banner.subtitle;

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ===== الطبقة السفلية: خلفية نابضة =====
            _background(),

            // ===== طبقة النص: شعار + عنوان متحرك على اليسار =====
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 8, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // شعار العلامة — ALAFIF NEWFORM
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'ALAFIF NEWFORM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _textFade,
                      child: ScaleTransition(
                        scale: _textScale,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      FadeTransition(
                        opacity: _textFade,
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ===== المنتج 1 (رئيسي): ينزلق من اليمين =====
            if (items.isNotEmpty)
              Align(
                alignment: const Alignment(0.5, -0.25),
                child: SlideTransition(
                  position: _item1Offset,
                  child: _productCard(items[0], 100, 132),
                ),
              ),

            // ===== المنتج 2 (ثانوي): ينزلق من الأسفل =====
            if (items.length > 1)
              Align(
                alignment: const Alignment(-0.25, 0.72),
                child: SlideTransition(
                  position: _item2Offset,
                  child: Transform.rotate(
                    angle: -0.04,
                    child: _productCard(items[1], 74, 92),
                  ),
                ),
              ),

            // ===== المنتج 3 (إكسسوار): تلاشي + طفو متكرر =====
            if (items.length > 2)
              Align(
                alignment: const Alignment(0.85, -0.65),
                child: FadeTransition(
                  opacity: _item3Fade,
                  child: AnimatedBuilder(
                    animation: _float,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _floatY.value),
                      child: child,
                    ),
                    child: Transform.rotate(
                      angle: 0.05,
                      child: _productCard(items[2], 56, 68),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
