import 'cart_item.dart';

/// شرائح خصم «الإطلالة الكاملة» (Full-Look Bundle Engine).
///
/// القاعدة الواحدة التي تحكم السلة وشاشة الدفع ومستند الطلب — فلا يمكن أن
/// تعرض الواجهة خصماً لا يُطبَّق فعلياً (وهو الخلل الذي كان قائماً حين كان
/// الخصم نصاً بصرياً فقط في واجهة الطقم).
class BundleTier {
  /// المفتاح المخزَّن في مستند الطلب
  final String key;

  /// الاسم المعروض
  final String label;

  /// أقل عدد قطع يؤهّل لهذه الشريحة
  final int minPieces;

  /// نسبة الخصم على مجموع قطع الطقم
  final double rate;

  const BundleTier._(this.key, this.label, this.minPieces, this.rate);

  /// أقل من قطعتين — لا خصم
  static const BundleTier none = BundleTier._('none', 'بدون خصم', 1, 0.0);

  /// قطعتان — إطلالة كاملة 10%
  static const BundleTier completeLook =
      BundleTier._('complete_look', 'إطلالة كاملة', 2, 0.10);

  /// ثلاث قطع أو أكثر — طقم كامل 15%
  static const BundleTier fullOutfit =
      BundleTier._('full_outfit', 'طقم كامل', 3, 0.15);

  int get percent => (rate * 100).round();
}

/// ملخص طقم واحد (مجموعة قطع جاءت من مصدر توصية واحد).
class BundleGroupSummary {
  /// معرّف المجموعة (إطلالة المصمّم الذكي أو طقم منسّق يدوياً)
  final String groupId;

  /// المصدر: `stylist` (توصية المصمم الذكي) أو `outfit` (طقم منسّق من الإدارة)
  final String source;

  /// عدد القطع المميّزة (المنتج نفسه بمقاسات مختلفة = قطعة واحدة)
  final int pieces;

  /// مجموع أسعار قطع المجموعة
  final double subtotal;

  final BundleTier tier;

  const BundleGroupSummary({
    required this.groupId,
    required this.source,
    required this.pieces,
    required this.subtotal,
    required this.tier,
  });

  double get discount => subtotal * tier.rate;

  double get discountedSubtotal => subtotal - discount;

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'source': source,
        'pieces': pieces,
        'tier': tier.key,
        'tierLabel': tier.label,
        'rate': tier.rate,
        'subtotal': subtotal,
        'discount': discount,
      };
}

/// ملخص كل الأطقم في السلة.
class BundleSummary {
  final List<BundleGroupSummary> groups;

  const BundleSummary(this.groups);

  static const BundleSummary empty = BundleSummary(<BundleGroupSummary>[]);

  bool get hasBundle => groups.isNotEmpty;

  /// مجموع قطع الأطقم (للعرض والتقدّم بين الشرائح)
  int get pieces =>
      groups.fold(0, (sum, g) => sum + g.pieces);

  /// مجموع أسعار قطع الأطقم
  double get subtotal => groups.fold(0.0, (sum, g) => sum + g.subtotal);

  /// إجمالي الخصم المستحق على الأطقم في السلة
  double get discountAmount =>
      groups.fold(0.0, (sum, g) => sum + g.discount);

  /// أفضل شريحة مُطبَّقة (الأعلى نسبة) — للعرض
  BundleTier get bestTier {
    var best = BundleTier.none;
    for (final g in groups) {
      if (g.tier.rate > best.rate) best = g.tier;
    }
    return best;
  }

  /// كم قطعة تفصل المستخدم عن الشريحة التالية (0 = لا شريحة تالية)
  int get piecesToNextTier {
    if (!hasBundle) return 0;
    final piecesInBest = groups
        .map((g) => g.pieces)
        .fold(0, (max, p) => p > max ? p : max);
    if (piecesInBest >= BundleTier.fullOutfit.minPieces) return 0;
    if (piecesInBest >= BundleTier.completeLook.minPieces) {
      return BundleTier.fullOutfit.minPieces - piecesInBest;
    }
    return BundleTier.completeLook.minPieces - piecesInBest;
  }

  /// الشريحة التي سيدخل فيها المستخدم بعد إضافة القطعة التالية
  BundleTier get nextTier {
    final piecesInBest = groups
        .map((g) => g.pieces)
        .fold(0, (max, p) => p > max ? p : max);
    return BundlePricing.tierFor(piecesInBest + 1);
  }

  /// نص لافتة التقدّم في السلة (فارغ إذا لا يوجد طقم في السلة)
  String progressHint(String Function(double) formatPrice) {
    if (!hasBundle) return '';
    final missing = piecesToNextTier;
    if (missing > 0) {
      final next = nextTier;
      return missing == 1
          ? 'أضف قطعة أخرى للحصول على خصم ${next.percent}% 🏷️'
          : 'أضف $missing قطع للحصول على خصم ${next.percent}% 🏷️';
    }
    return 'تم تطبيق خصم ${bestTier.percent}% على الطقم 🎉 — وفّرت '
        '${formatPrice(discountAmount)}';
  }

  /// بيانات الطقم كما تُخزَّن في مستند الطلب (ليرى الموظفون التفصيل)
  Map<String, dynamic> toMap() => {
        'tier': bestTier.key,
        'tierLabel': bestTier.label,
        'rate': bestTier.rate,
        'pieces': pieces,
        'subtotal': subtotal,
        'discount': discountAmount,
        'groups': groups.map((g) => g.toMap()).toList(),
      };
}

/// محرك حساب خصم الطقم.
///
/// يُستخدم في ثلاثة أماكن بنفس القواعد:
/// 1. `CartProvider` — لإظهار الخصم واللافتة في السلة والدفع.
/// 2. `OrderProvider` — لكتابة الخصم والتفصيل في مستند الطلب.
/// 3. واجهة الطقم في صفحة المنتج — لعرض نفس الرقم الذي سيُخصم فعلاً.
class BundlePricing {
  const BundlePricing._();

  /// القطع التي تدخل في حساب الطقم: ما أُضيف من توصية المصمم الذكي
  /// أو من الطقم المنسّق في الإدارة (لها `bundleGroupId`).
  static List<CartItem> eligibleItems(List<CartItem> items) =>
      items.where((i) => i.bundleGroupId.isNotEmpty).toList();

  /// الشريحة المقابلة لعدد القطع
  static BundleTier tierFor(int pieces) {
    if (pieces >= BundleTier.fullOutfit.minPieces) {
      return BundleTier.fullOutfit;
    }
    if (pieces >= BundleTier.completeLook.minPieces) {
      return BundleTier.completeLook;
    }
    return BundleTier.none;
  }

  /// يجمّع قطع السلة في أطقم ويحسب خصم كل طقم.
  static BundleSummary summarize(List<CartItem> items) {
    final groups = <String, List<CartItem>>{};
    for (final item in eligibleItems(items)) {
      groups.putIfAbsent(item.bundleGroupId, () => []).add(item);
    }
    if (groups.isEmpty) return BundleSummary.empty;

    final summaries = <BundleGroupSummary>[];
    groups.forEach((groupId, groupItems) {
      // القطعة = منتج مميّز؛ نفس المنتج بمقاسين لا يُحسب قطعتين.
      final distinctProducts = <String>{};
      var subtotal = 0.0;
      var source = '';
      for (final item in groupItems) {
        distinctProducts.add(item.product.id);
        subtotal += item.totalPrice;
        if (source.isEmpty) source = item.bundleSource;
      }
      final pieces = distinctProducts.length;
      summaries.add(
        BundleGroupSummary(
          groupId: groupId,
          source: source,
          pieces: pieces,
          subtotal: subtotal,
          tier: tierFor(pieces),
        ),
      );
    });

    return BundleSummary(summaries);
  }
}
