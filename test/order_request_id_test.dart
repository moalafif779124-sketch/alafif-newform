import 'package:flutter_test/flutter_test.dart';
import 'package:alafif_newform/utils/order_request_id.dart';

void main() {
  group('OrderRequestId.generate', () {
    test('يطابق صيغة معرّف مستند صالح', () {
      for (var i = 0; i < 100; i++) {
        final id = OrderRequestId.generate();
        expect(OrderRequestId.isValid(id), isTrue, reason: id);
        expect(id.startsWith('req'), isTrue);
        expect(id.length, lessThanOrEqualTo(64));
        expect(id.length, greaterThanOrEqualTo(8));
      }
    });

    test('فريد عبر 2000 توليد متتالٍ', () {
      final seen = <String>{};
      for (var i = 0; i < 2000; i++) {
        expect(seen.add(OrderRequestId.generate()), isTrue);
      }
    });

    test('الطابع الزمني يُدمج في المعرّف', () {
      final t = DateTime.fromMillisecondsSinceEpoch(1765160000000);
      final a = OrderRequestId.generate(t);
      final b = OrderRequestId.generate(t);
      expect(a.substring(3).startsWith(t.millisecondsSinceEpoch.toRadixString(36)), isTrue);
      expect(a, isNot(b)); // العشوائي يختلف دائماً
    });
  });

  group('OrderRequestId.isValid', () {
    test('يرفض الفارغ والرموز والمسافات', () {
      expect(OrderRequestId.isValid(null), isFalse);
      expect(OrderRequestId.isValid(''), isFalse);
      expect(OrderRequestId.isValid('short'), isFalse);
      expect(OrderRequestId.isValid('req/withSlash123'), isFalse);
      expect(OrderRequestId.isValid('req with space 1'), isFalse);
      expect(OrderRequestId.isValid('req#1234567890'), isFalse);
    });

    test('يقبل الحروف والأرقام فقط', () {
      expect(OrderRequestId.isValid('reqabc123XYZ0'), isTrue);
    });

    test('يرفض أكثر من 64 حرفاً', () {
      expect(OrderRequestId.isValid('a' * 65), isFalse);
      expect(OrderRequestId.isValid('a' * 64), isTrue);
    });
  });
}
