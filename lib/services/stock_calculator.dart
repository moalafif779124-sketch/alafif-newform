// حساب تحديث المخزون — دالة نقية (بلا Firestore) كي تُختبر وحدها.
//
// المنطق يطابق ما تعرضه شاشة المنتج:
//  * المنتج له مقاسات (stockVariants غير فارغة) → الحجز من مخزون المقاس نفسه.
//  * لا مقاسات وstockQuantity > 0 → الحجز من الكمية الكلية.
//  * الاثنان صفر/فارغ → مخزون غير مُتتبَّع: لا حجب ولا خصم.

/// يُرمى عندما لا تكفي الكمية المطلوبة في المخزون — الطلب لا يُنشأ إطلاقاً.
class StockUnavailableException implements Exception {
  final String message;
  final String? productName;
  final String? size;
  StockUnavailableException(this.message, {this.productName, this.size});
  @override
  String toString() => message;
}

class StockUpdate {
  /// القيم الجديدة التي تُكتب في مستند المنتج.
  final int stockQuantity;
  final Map<String, int> stockVariants;

  /// هل المنتج مُتتبَّع (له مخزون مسجّل)؟ غير المُتتبَّع لا يُكتب له شيء.
  final bool tracked;

  const StockUpdate({
    required this.stockQuantity,
    required this.stockVariants,
    required this.tracked,
  });
}

/// يحسب المخزون الجديد بعد بيع [requestedTotal] وحدة، موزّعة على
/// [requestedBySize] لمقاسات محددة.
///
/// يرمي [StockUnavailableException] إذا لم تكفِ الكمية، ولا يُعيد تحديثاً
/// جزئياً أبداً.
StockUpdate computeStockUpdate({
  required String productName,
  required Map<String, int> stockVariants,
  required int stockQuantity,
  required int requestedTotal,
  required Map<String, int> requestedBySize,
}) {
  final variants = Map<String, int>.from(stockVariants);
  final tracked = variants.isNotEmpty || stockQuantity > 0;

  // مخزون غير مُتتبَّع → لا حجب ولا خصم
  if (!tracked) {
    return StockUpdate(
      stockQuantity: stockQuantity,
      stockVariants: variants,
      tracked: false,
    );
  }

  if (variants.isNotEmpty) {
    if (requestedBySize.isEmpty) {
      throw StockUnavailableException(
        'المنتج «$productName» يُباع حسب المقاس — أعد إضافته واختر المقاس',
        productName: productName,
      );
    }
    for (final entry in requestedBySize.entries) {
      final have = variants[entry.key] ?? 0;
      if (have < entry.value) {
        throw StockUnavailableException(
          'الكمية المطلوبة من «$productName» (مقاس ${entry.key}) غير متوفرة — '
          'المتاح $have',
          productName: productName,
          size: entry.key,
        );
      }
      variants[entry.key] = have - entry.value;
    }
    var newTotal = stockQuantity;
    if (newTotal > 0) {
      newTotal -= requestedTotal;
      if (newTotal < 0) newTotal = 0;
    }
    return StockUpdate(
      stockQuantity: newTotal,
      stockVariants: variants,
      tracked: true,
    );
  }

  // بلا مقاسات → الكمية الكلية فقط
  if (stockQuantity < requestedTotal) {
    throw StockUnavailableException(
      'الكمية المطلوبة من «$productName» غير متوفرة — المتاح $stockQuantity',
      productName: productName,
    );
  }
  return StockUpdate(
    stockQuantity: stockQuantity - requestedTotal,
    stockVariants: variants,
    tracked: true,
  );
}
