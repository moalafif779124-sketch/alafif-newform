import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../models/product.dart';

/// حساب المقاس الأنسب بناءً على الطول والوزن، متكيّف مع فئة المنتج
///
/// - الفئات الرسمية (بدلات/ثياب/بذل): مقاسات رقمية (46-54)
/// - الفئات الكاجوال (فنايل/جاكتات/بجائم): مقاسات حرفية (S-XXL)
String calculateRecommendedSize({
  required Product product,
  required double heightCm,
  required double weightKg,
}) {
  final catName = product.categoryName.toLowerCase();
  final catId = product.categoryId.toLowerCase();

  // ===== هل هذه فئة مقاسات رقمية (رسمية/بدلات/ثياب)؟ =====
  final isNumericCategory = catName.contains('بدلات') ||
      catName.contains('بذل') ||
      catName.contains('ثياب') ||
      catName.contains('ثوب') ||
      catId.contains('badlat') ||
      catId.contains('suit') ||
      catId.contains('thob');

  if (isNumericCategory) {
    // ===== مقاسات رقمية رسمية (46, 48, 50, 52, 54) =====
    String recommended;
    if (weightKg < 65) {
      recommended = '46';
    } else if (weightKg < 75) {
      recommended = '48';
    } else if (weightKg < 85) {
      recommended = '50';
    } else if (weightKg < 95) {
      recommended = '52';
    } else {
      recommended = '54';
    }
    return _snapToAvailable(recommended, product.sizes, numeric: true);
  }

  // ===== مقاسات حرفية كاجوال (S, M, L, XL, XXL) — مؤشر كتلة الجسم =====
  final bmi = weightKg / ((heightCm / 100) * (heightCm / 100));
  String recommended;
  if (bmi < 19) {
    recommended = 'S';
  } else if (bmi < 23) {
    recommended = 'M';
  } else if (bmi < 26) {
    recommended = 'L';
  } else if (bmi < 30) {
    recommended = 'XL';
  } else {
    recommended = 'XXL';
  }
  return _snapToAvailable(recommended, product.sizes, numeric: false);
}

/// تقريب المقاس الموصى به إلى أقرب مقاس متاح فعلياً في المنتج
String _snapToAvailable(String recommended, List<String> sizes,
    {required bool numeric}) {
  if (sizes.isEmpty) return recommended;
  if (sizes.contains(recommended)) return recommended;

  // حاول مطابقة قريبة: انظر للمقاسات المتاحة
  if (numeric) {
    final recNum = int.tryParse(recommended);
    if (recNum != null) {
      // أقرب مقاس رقمي
      String? best;
      int? bestDiff;
      for (final s in sizes) {
        final n = int.tryParse(s.trim());
        if (n == null) continue;
        final diff = (n - recNum).abs();
        if (best == null || diff < bestDiff!) {
          best = s;
          bestDiff = diff;
        }
      }
      if (best != null) return best;
    }
  } else {
    // ترتيب المقاسات الحرفية
    const order = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
    final recIdx = order.indexOf(recommended);
    if (recIdx >= 0) {
      String? best;
      int? bestDiff;
      for (final s in sizes) {
        final idx = order.indexOf(s.trim().toUpperCase());
        if (idx < 0) continue;
        final diff = (idx - recIdx).abs();
        if (best == null || diff < bestDiff!) {
          best = s;
          bestDiff = diff;
        }
      }
      if (best != null) return best;
    }
  }
  return recommended;
}

/// ورقة المقاسات الذكية — نافذة سفلية بحساب فوري للمقاس
class VirtualSizeGuideSheet extends StatefulWidget {
  final Product product;
  final ValueChanged<String> onApply;

  const VirtualSizeGuideSheet({
    super.key,
    required this.product,
    required this.onApply,
  });

  @override
  State<VirtualSizeGuideSheet> createState() => _VirtualSizeGuideSheetState();
}

class _VirtualSizeGuideSheetState extends State<VirtualSizeGuideSheet> {
  double _height = 175; // سم
  double _weight = 75; // كغ

  String get _recommended => calculateRecommendedSize(
        product: widget.product,
        heightCm: _height,
        weightKg: _weight,
      );

  @override
  Widget build(BuildContext context) {
    final recommended = _recommended;
    final inStock = widget.product.sizes.contains(recommended);

    return SafeArea(
      child: Padding(
        // حماية من لوحة المفاتيح
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // مقبض السحب
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // العنوان
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.amazonBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.straighten,
                        color: AppColors.amazonBlue, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دليل المقاسات الذكي 📏',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'أدخل طولك ووزنك لنقترح عليك المقاس الأنسب',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ===== شريحة الطول =====
              _buildSliderLabel(
                icon: Icons.height,
                label: 'الطول',
                value: _height,
                unit: 'سم',
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.amazonBlue,
                  inactiveTrackColor: AppColors.amazonBlue.withValues(alpha: 0.15),
                  thumbColor: AppColors.amazonBlue,
                  overlayColor: AppColors.amazonBlue.withValues(alpha: 0.15),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 150,
                  max: 210,
                  divisions: 60,
                  value: _height,
                  label: '${_height.round()} سم',
                  onChanged: (v) => setState(() => _height = v),
                ),
              ),
              const SizedBox(height: 8),

              // ===== شريحة الوزن =====
              _buildSliderLabel(
                icon: Icons.monitor_weight_outlined,
                label: 'الوزن',
                value: _weight,
                unit: 'كغ',
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.amazonOrange,
                  inactiveTrackColor:
                      AppColors.amazonOrange.withValues(alpha: 0.15),
                  thumbColor: AppColors.amazonOrange,
                  overlayColor: AppColors.amazonOrange.withValues(alpha: 0.15),
                  trackHeight: 4,
                ),
                child: Slider(
                  min: 45,
                  max: 130,
                  divisions: 85,
                  value: _weight,
                  label: '${_weight.round()} كغ',
                  onChanged: (v) => setState(() => _weight = v),
                ),
              ),
              const SizedBox(height: 16),

              // ===== النتيجة الموصى بها =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.amazonNavy,
                      AppColors.amazonBlue,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text(
                      'المقاس الأنسب لك هو',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recommended,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!inStock) ...[
                      const SizedBox(height: 8),
                      Text(
                        '⚠️ هذا المقاس غير متوفر حالياً — سيتم اختياره على مسؤوليتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ===== زر اعتماد المقاس =====
              ElevatedButton(
                onPressed: () {
                  widget.onApply(recommended);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amazonYellow,
                  foregroundColor: AppColors.amazonDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 8),
                    Text('اعتماد المقاس'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'التوصية مبنية على مقاييس عامة وقد تختلف حسب القصّة والقماش',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderLabel({
    required IconData icon,
    required String label,
    required double value,
    required String unit,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${value.round()} $unit',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// فتح ورقة المقاسات الذكية
Future<void> showVirtualSizeGuide({
  required BuildContext context,
  required Product product,
  required ValueChanged<String> onApply,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: VirtualSizeGuideSheet(product: product, onApply: onApply),
    ),
  );
}
