import 'package:flutter_test/flutter_test.dart';
import 'package:alafif_newform/services/stock_calculator.dart';

void main() {
  group('computeStockUpdate — الكمية الكلية (بلا مقاسات)', () {
    test('خصم عادي', () {
      final u = computeStockUpdate(
        productName: 'تي شرت',
        stockVariants: const {},
        stockQuantity: 15,
        requestedTotal: 3,
        requestedBySize: const {},
      );
      expect(u.tracked, isTrue);
      expect(u.stockQuantity, 12);
    });

    test('كمية أكبر من المخزون تُرفض', () {
      expect(
        () => computeStockUpdate(
          productName: 'تي شرت',
          stockVariants: const {},
          stockQuantity: 15,
          requestedTotal: 16,
          requestedBySize: const {},
        ),
        throwsA(isA<StockUnavailableException>()
            .having((e) => e.message, 'message', contains('المتاح 15'))),
      );
    });

    test('بيع كل الكمية يوصل إلى صفر لا سالب', () {
      final u = computeStockUpdate(
        productName: 'طقم',
        stockVariants: const {},
        stockQuantity: 4,
        requestedTotal: 4,
        requestedBySize: const {},
      );
      expect(u.stockQuantity, 0);
    });

    test('مخزون غير مُتتبَّع (صفر بلا مقاسات) لا يُحجب ولا يُخصم', () {
      final u = computeStockUpdate(
        productName: 'منتج قديم',
        stockVariants: const {},
        stockQuantity: 0,
        requestedTotal: 99,
        requestedBySize: const {},
      );
      expect(u.tracked, isFalse);
      expect(u.stockQuantity, 0);
    });
  });

  group('computeStockUpdate — مقاسات', () {
    test('خصم من المقاس نفسه مع تنقيص الإجمالي', () {
      final u = computeStockUpdate(
        productName: 'بدلة',
        stockVariants: const {'46': 30, '48': 7, '50': 6, '52': 3},
        stockQuantity: 3,
        requestedTotal: 2,
        requestedBySize: const {'52': 2},
      );
      expect(u.stockVariants['52'], 1);
      expect(u.stockVariants['48'], 7, reason: 'بقية المقاسات لا تُمَس');
      expect(u.stockQuantity, 1);
    });

    test('مقاس غير متوفر يُرفض', () {
      expect(
        () => computeStockUpdate(
          productName: 'بدلة',
          stockVariants: const {'46': 30, '48': 7, '50': 6, '52': 3},
          stockQuantity: 3,
          requestedTotal: 4,
          requestedBySize: const {'52': 4},
        ),
        throwsA(isA<StockUnavailableException>()
            .having((e) => e.size, 'size', '52')),
      );
    });

    test('مقاسات كلها صفر → كل مقاس منفذ', () {
      expect(
        () => computeStockUpdate(
          productName: 'يلقات',
          stockVariants: const {'S': 0, 'M': 0, 'L': 0},
          stockQuantity: 0,
          requestedTotal: 1,
          requestedBySize: const {'M': 1},
        ),
        throwsA(isA<StockUnavailableException>()),
      );
    });

    test('منتج بمقاسات وطلب بلا مقاس يُرفض برسالة واضحة', () {
      expect(
        () => computeStockUpdate(
          productName: 'بدلة',
          stockVariants: const {'48': 7},
          stockQuantity: 7,
          requestedTotal: 1,
          requestedBySize: const {},
        ),
        throwsA(isA<StockUnavailableException>()
            .having((e) => e.message, 'message', contains('حسب المقاس'))),
      );
    });
  });
}
