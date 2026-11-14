import 'package:flutter_test/flutter_test.dart';
import 'package:alafif_newform/models/bundle_pricing.dart';

/// اختبارات قواعد شرائح خصم الطقم (Full-Look Bundle Engine).
///
/// المحرك هو المصدر الوحيد للحقيقة: السلة، لافتة التقدّم، شاشة الدفع،
/// ومستند الطلب — فأي خطأ في هذه القواعد يعني خصماً معروضاً وغير محسوب.
void main() {
  group('شرائح الخصم', () {
    test('قطعة واحدة = بلا خصم', () {
      expect(BundlePricing.tierFor(1), BundleTier.none);
      expect(BundlePricing.tierFor(1).rate, 0.0);
      expect(BundlePricing.tierFor(1).percent, 0);
    });

    test('قطعتان = إطلالة كاملة 10%', () {
      expect(BundlePricing.tierFor(2), BundleTier.completeLook);
      expect(BundlePricing.tierFor(2).rate, 0.10);
      expect(BundlePricing.tierFor(2).percent, 10);
    });

    test('ثلاث قطع أو أكثر = طقم كامل 15%', () {
      expect(BundlePricing.tierFor(3), BundleTier.fullOutfit);
      expect(BundlePricing.tierFor(4), BundleTier.fullOutfit);
      expect(BundlePricing.tierFor(7).rate, 0.15);
      expect(BundlePricing.tierFor(7).percent, 15);
    });
  });

  group('لافتة التقدّم', () {
    BundleGroupSummary group(int pieces) => BundleGroupSummary(
          groupId: 'g',
          source: 'stylist',
          pieces: pieces,
          subtotal: 1000,
          tier: BundlePricing.tierFor(pieces),
        );

    test('قطعة واحدة تدعو لخصم 10%', () {
      final hint = BundleSummary([group(1)]).progressHint((v) => '$v');
      expect(hint, contains('خصم 10%'));
      expect(BundleSummary([group(1)]).piecesToNextTier, 1);
    });

    test('قطعتان تدعوان للشريحة التالية 15% (نص المطلوب)', () {
      final summary = BundleSummary([group(2)]);
      expect(summary.piecesToNextTier, 1);
      expect(summary.nextTier, BundleTier.fullOutfit);
      expect(
        summary.progressHint((v) => '$v'),
        'أضف قطعة أخرى للحصول على خصم 15% 🏷️',
      );
    });

    test('ثلاث قطع تطبّق 15% وتؤكد التوفير', () {
      final summary = BundleSummary([group(3)]);
      expect(summary.piecesToNextTier, 0);
      expect(summary.discountAmount, 150.0); // 15% من 1000
      expect(summary.progressHint((v) => v.toStringAsFixed(0)),
          contains('خصم 15%'));
    });
  });

  group('حساب الخصم', () {
    test('الخصم = النسبة × مجموع قطع الطقم', () {
      final two = BundleSummary([
        BundleGroupSummary(
          groupId: 'g',
          source: 'outfit',
          pieces: 2,
          subtotal: 20000,
          tier: BundlePricing.tierFor(2),
        ),
      ]);
      expect(two.discountAmount, 2000.0); // 10%

      final three = BundleSummary([
        BundleGroupSummary(
          groupId: 'g',
          source: 'outfit',
          pieces: 3,
          subtotal: 20000,
          tier: BundlePricing.tierFor(3),
        ),
      ]);
      expect(three.discountAmount, 3000.0); // 15%
    });

    test('طقم بلا خصم لا يُحسب ضمن discountAmount', () {
      final single = BundleSummary([
        BundleGroupSummary(
          groupId: 'g',
          source: 'stylist',
          pieces: 1,
          subtotal: 5000,
          tier: BundlePricing.tierFor(1),
        ),
      ]);
      expect(single.discountAmount, 0.0);
      expect(single.hasBundle, isTrue); // القطعة موجودة لكن بلا خصم بعد
    });

    test('بيانات الطقم تُخزَّن في مستند الطلب', () {
      final summary = BundleSummary([
        BundleGroupSummary(
          groupId: 'stylist_1',
          source: 'stylist',
          pieces: 3,
          subtotal: 10000,
          tier: BundlePricing.tierFor(3),
        ),
      ]);
      final map = summary.toMap();
      expect(map['tier'], 'full_outfit');
      expect(map['tierLabel'], 'طقم كامل');
      expect(map['pieces'], 3);
      expect(map['discount'], 1500.0);
      expect((map['groups'] as List).length, 1);
    });
  });
}
